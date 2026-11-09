using System.Reflection;
using DbUp;
using DbUp.Helpers;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

var config = new ConfigurationBuilder()
    .AddUserSecrets(Assembly.GetExecutingAssembly())
    .AddEnvironmentVariables()
    .Build();

var connectionString = config["ConnectionStrings:Identity"];
if (string.IsNullOrWhiteSpace(connectionString))
{
    Console.Error.WriteLine("ConnectionStrings:Identity is not set.");
    return 1;
}

Console.WriteLine("Connection string found, it is " + connectionString.Length + "chars long.");


var root = FindIdentityFolder();
Console.WriteLine($"scripts: {root}");

var master = new SqlConnectionStringBuilder(connectionString) { InitialCatalog = "master" }.ConnectionString;

var bootstrap = DeployChanges.To
    .SqlDatabase(master)
    .WithScriptsFromFileSystem(root, f => Path.GetFileName(f) == "bootstrap.sql")
    .JournalTo(new NullJournal())
    .LogToConsole()
    .Build();


var migration = DeployChanges.To
    .SqlDatabase(connectionString)
    .WithScriptsFromFileSystem(Path.Combine(root, "migrations"))
    .WithTransactionPerScript()
    .LogToConsole()
    .Build();

var triggers = DeployChanges.To
    .SqlDatabase(connectionString)
    .WithScriptsFromFileSystem(Path.Combine(root, "triggers"))
    .JournalTo(new NullJournal())
    .WithTransactionPerScript()
    .LogToConsole()
    .Build();

foreach (var step in new[] { bootstrap, migration, triggers} )
{
    var result = step.PerformUpgrade();

    if(!result.Successful)
    {
        Console.ForegroundColor = ConsoleColor.Red;
        Console.WriteLine(result.Error);
        Console.ResetColor();
        return 1;
    }

}

Console.WriteLine("Database is upto date");
return 0;

static string FindIdentityFolder()
{
    var dir = new DirectoryInfo(AppContext.BaseDirectory);
    while (dir != null)
    {
        var candidate = Path.Combine(dir.FullName, "database", "identity");
        if (Directory.Exists(candidate))
            return candidate;
        dir = dir.Parent;
    }
    throw new DirectoryNotFoundException("could not find database/identity above " + AppContext.BaseDirectory);
}