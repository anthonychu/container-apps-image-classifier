using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.AspNetCore.Mvc;
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

app.MapPost("/submitimages", async ctx =>
{
    var numImages = Convert.ToInt32(ctx.Request.Query.Single(x => x.Key == "numimages").Value.ToString());
    numImages = Math.Min(Math.Abs(numImages), 1000);
    var rand = new Random();
    var tasks = Enumerable.Range(0, numImages).Select(_ =>
    {
        var imageNum = rand.Next(1, 500);
        var folder = new string[] {"Cat", "Dog"}[rand.Next(0, 2)];
        var filename = $"{folder}/{imageNum}.jpg";
        System.Console.WriteLine($"{filename}");
        return queueClient.SendMessageAsync($"https://pythonqueueimage.blob.core.windows.net/images/{filename}");
    });

    await Task.WhenAll(tasks);

    ctx.Response.ContentType = "text/plain";
    await ctx.Response.WriteAsync(numImages.ToString());
});

app.MapPost("/result", async (HttpContext ctx, [FromBody] object progress) =>
{
    var hubContext = ctx.RequestServices
        .GetRequiredService<IHubContext<ProgressHub>>();
    await hubContext.Clients.All.SendAsync("NewProgress", progress);
});

app.MapHub<ProgressHub>("/progress");

app.UseDefaultFiles();
app.UseStaticFiles();

app.Run();
