using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.AspNetCore.SignalR;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSignalR();

var app = builder.Build();

var queueName = builder.Configuration["AZURE_QUEUE_NAME"];
var queueUrl = $"{builder.Configuration["AZURE_QUEUE_SERVICE_URL"]}{queueName}";
System.Console.WriteLine(queueUrl);
var credential = new DefaultAzureCredential();
var queueClient = new QueueClient(new Uri(queueUrl), credential, new QueueClientOptions
{
    MessageEncoding = QueueMessageEncoding.Base64
});

app.UseFileServer();

var imagesBaseUrl = builder.Configuration["AZURE_STORAGE_STATIC_WEBSITE_URL"];
app.MapPost("/submitimages", async (int numImages) =>
{
    numImages = Math.Min(Math.Abs(numImages), 1000);
    var tasks = Enumerable.Range(0, numImages).Select(_ =>
    {
        var imageNum = Random.Shared.Next(0, 1000);
        var filename = $"{imageNum}.jpg";
        System.Console.WriteLine($"{filename}");
        return queueClient.SendMessageAsync($"{imagesBaseUrl}{filename}");
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
