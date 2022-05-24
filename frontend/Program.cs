using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.AspNetCore.SignalR;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSignalR();

var app = builder.Build();

var url = $"{builder.Configuration["AZURE_QUEUE_SERVICE_URL"]}/images";
System.Console.WriteLine(url);
var credential = new DefaultAzureCredential();
var queueClient = new QueueClient(new Uri(url), credential, new QueueClientOptions
{
    MessageEncoding = QueueMessageEncoding.Base64
});

var folders = new string[] { "Cat", "Dog" };

app.UseFileServer();

app.MapPost("/submitimages", async (int numImages) =>
{
    numImages = Math.Min(Math.Abs(numImages), 1000);
    var tasks = Enumerable.Range(0, numImages).Select(_ =>
    {
        var imageNum = Random.Shared.Next(1, 500);
        var folder = folders[Random.Shared.Next(0, 2)];
        var filename = $"{folder}/{imageNum}.jpg";
        System.Console.WriteLine($"{filename}");
        return queueClient.SendMessageAsync($"https://pythonqueueimage.blob.core.windows.net/images/{filename}");
    });

    await Task.WhenAll(tasks);

    return numImages.ToString();
});

app.MapPost("/result", async (object progress, IHubContext<ProgressHub> hubContext) =>
{
    await hubContext.Clients.All.SendAsync("NewProgress", progress);
});

app.MapHub<ProgressHub>("/progress");

app.Run();
