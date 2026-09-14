using Contoso.Fabric.Api.Data;
using Contoso.Fabric.Api.Search;
using Contoso.Fabric.SharedLib;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("OrdersDb");

// No connection string (CI, local dev, container smoke tests) falls back to seed data.
if (string.IsNullOrWhiteSpace(connectionString))
{
    builder.Services.AddSingleton<IOrdersRepository, InMemoryOrdersRepository>();
}
else
{
    builder.Services.AddSingleton<IOrdersRepository>(_ => new OrdersRepository(connectionString));
}

var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.MapGet("/orders/search", async (
    string? q,
    IOrdersRepository repository,
    CancellationToken cancellationToken) =>
{
    if (!SearchTerm.TryNormalize(q, out var term, out var error))
    {
        return Results.BadRequest(new { error });
    }

    var orders = await repository.SearchAsync(term, cancellationToken);
    return Results.Ok(orders);
});

app.MapGet("/orders/{id:int}", async (
    int id,
    IOrdersRepository repository,
    CancellationToken cancellationToken) =>
{
    var order = await repository.GetByIdAsync(id, cancellationToken);
    return order is null ? Results.NotFound() : Results.Ok(order);
});

app.MapGet("/orders/{id:int}/totals", async (
    int id,
    LoyaltyTier tier,
    IOrdersRepository repository,
    CancellationToken cancellationToken) =>
{
    var order = await repository.GetByIdAsync(id, cancellationToken);
    if (order is null)
    {
        return Results.NotFound();
    }

    var lines = new[] { new OrderLine(order.Sku, order.Quantity, order.UnitPrice) };
    return Results.Ok(PricingCalculator.Calculate(lines, tier, taxRate: 0.15m));
});

app.Run();
