namespace Contoso.Fabric.Api.Models;

public sealed record Order(
    int Id,
    string Customer,
    string Sku,
    int Quantity,
    decimal UnitPrice,
    string Status,
    DateTime CreatedUtc);
