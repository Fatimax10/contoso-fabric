namespace Contoso.Fabric.SharedLib;

/// <summary>Customer loyalty tier, which determines the base discount rate.</summary>
public enum LoyaltyTier
{
    Standard = 0,
    Silver = 1,
    Gold = 2,
    Platinum = 3,
}

public sealed record OrderLine(string Sku, int Quantity, decimal UnitPrice);

public sealed record OrderTotals(
    decimal Subtotal,
    decimal Discount,
    decimal Tax,
    decimal ShippingCost,
    decimal Total);

/// <summary>
/// Pure pricing rules. Deliberately free of I/O, clocks, and ambient state so it can be
/// unit tested without any test doubles.
/// </summary>
public static class PricingCalculator
{
    private const decimal FreeShippingThreshold = 75.00m;
    private const decimal StandardShippingCost = 6.95m;

    /// <summary>Bulk discount applied per line when the quantity reaches a break point.</summary>
    private static readonly (int Quantity, decimal Rate)[] BulkBreaks =
    [
        (50, 0.15m),
        (20, 0.10m),
        (10, 0.05m),
    ];

    public static decimal DiscountRateFor(LoyaltyTier tier) => tier switch
    {
        LoyaltyTier.Platinum => 0.15m,
        LoyaltyTier.Gold => 0.10m,
        LoyaltyTier.Silver => 0.05m,
        _ => 0.00m,
    };

    public static decimal BulkDiscountRateFor(int quantity)
    {
        foreach (var (breakQuantity, rate) in BulkBreaks)
        {
            if (quantity >= breakQuantity)
            {
                return rate;
            }
        }

        return 0.00m;
    }

    /// <summary>
    /// Calculates the totals for an order. Loyalty and bulk discounts stack additively and are
    /// capped at 25% so that a Platinum customer buying in bulk can never erase the margin.
    /// Tax is charged on the discounted subtotal, not the gross.
    /// </summary>
    /// <exception cref="ArgumentException">A line has a non-positive quantity or negative price.</exception>
    public static OrderTotals Calculate(
        IReadOnlyCollection<OrderLine> lines,
        LoyaltyTier tier,
        decimal taxRate)
    {
        ArgumentNullException.ThrowIfNull(lines);

        if (taxRate is < 0m or > 1m)
        {
            throw new ArgumentOutOfRangeException(
                nameof(taxRate), taxRate, "Tax rate must be between 0 and 1.");
        }

        decimal subtotal = 0m;
        decimal discount = 0m;
        var loyaltyRate = DiscountRateFor(tier);

        foreach (var line in lines)
        {
            if (line.Quantity <= 0)
            {
                throw new ArgumentException(
                    $"Line '{line.Sku}' has a non-positive quantity.", nameof(lines));
            }

            if (line.UnitPrice < 0m)
            {
                throw new ArgumentException(
                    $"Line '{line.Sku}' has a negative unit price.", nameof(lines));
            }

            var lineTotal = line.UnitPrice * line.Quantity;
            var lineRate = Math.Min(loyaltyRate + BulkDiscountRateFor(line.Quantity), 0.25m);

            subtotal += lineTotal;
            discount += Round(lineTotal * lineRate);
        }

        var discounted = subtotal - discount;
        var shipping = discounted >= FreeShippingThreshold || subtotal == 0m
            ? 0m
            : StandardShippingCost;
        var tax = Round(discounted * taxRate);

        return new OrderTotals(
            Round(subtotal),
            Round(discount),
            tax,
            shipping,
            Round(discounted + tax + shipping));
    }

    private static decimal Round(decimal value) =>
        Math.Round(value, 2, MidpointRounding.AwayFromZero);
}
