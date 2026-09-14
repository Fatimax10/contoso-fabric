using Contoso.Fabric.Api.Models;

namespace Contoso.Fabric.Api.Data;

/// <summary>Seed data used whenever no SQL connection string is configured, including in CI.</summary>
public sealed class InMemoryOrdersRepository : IOrdersRepository
{
    private static readonly DateTime Epoch = new(2026, 1, 4, 9, 30, 0, DateTimeKind.Utc);

    private readonly List<Order> _orders =
    [
        new(1001, "Northwind Textiles", "FAB-LINEN-01", 12, 24.50m, "Shipped", Epoch),
        new(1002, "Aurora Interiors", "FAB-VELVET-07", 4, 61.00m, "Processing", Epoch.AddDays(3)),
        new(1003, "Northwind Textiles", "FAB-COTTON-22", 60, 8.75m, "Shipped", Epoch.AddDays(9)),
        new(1004, "Meridian Studio", "FAB-SILK-13", 2, 145.00m, "Pending", Epoch.AddDays(14)),
        new(1005, "Aurora Interiors", "FAB-LINEN-01", 25, 24.50m, "Cancelled", Epoch.AddDays(21)),
    ];

    public Task<IReadOnlyList<Order>> SearchAsync(
        string searchTerm,
        CancellationToken cancellationToken)
    {
        IReadOnlyList<Order> results = _orders
            .Where(o =>
                o.Customer.Contains(searchTerm, StringComparison.OrdinalIgnoreCase) ||
                o.Sku.Contains(searchTerm, StringComparison.OrdinalIgnoreCase))
            .OrderByDescending(o => o.CreatedUtc)
            .ToList();

        return Task.FromResult(results);
    }

    public Task<Order?> GetByIdAsync(int id, CancellationToken cancellationToken) =>
        Task.FromResult(_orders.FirstOrDefault(o => o.Id == id));
}
