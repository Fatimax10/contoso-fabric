using Contoso.Fabric.Api.Data;
using FluentAssertions;
using Xunit;

namespace Contoso.Fabric.Api.Tests;

public sealed class InMemoryOrdersRepositoryTests
{
    private readonly InMemoryOrdersRepository _repository = new();

    [Fact]
    public async Task SearchAsync_MatchingCustomer_ReturnsAllOrdersForThatCustomer()
    {
        var results = await _repository.SearchAsync("Northwind", CancellationToken.None);

        results.Should().HaveCount(2);
        results.Should().OnlyContain(o => o.Customer == "Northwind Textiles");
    }

    [Fact]
    public async Task SearchAsync_MatchingSku_ReturnsOrdersAcrossCustomers()
    {
        var results = await _repository.SearchAsync("FAB-LINEN-01", CancellationToken.None);

        results.Should().HaveCount(2);
        results.Select(o => o.Customer).Should().BeEquivalentTo(
            ["Northwind Textiles", "Aurora Interiors"]);
    }

    [Fact]
    public async Task SearchAsync_IsCaseInsensitive()
    {
        var results = await _repository.SearchAsync("nOrThWiNd", CancellationToken.None);

        results.Should().NotBeEmpty();
    }

    [Fact]
    public async Task SearchAsync_ReturnsNewestFirst()
    {
        var results = await _repository.SearchAsync("FAB", CancellationToken.None);

        results.Should().BeInDescendingOrder(o => o.CreatedUtc);
    }

    [Fact]
    public async Task SearchAsync_NoMatch_ReturnsEmpty()
    {
        var results = await _repository.SearchAsync("does-not-exist", CancellationToken.None);

        results.Should().BeEmpty();
    }

    [Fact]
    public async Task GetByIdAsync_KnownId_ReturnsOrder()
    {
        var order = await _repository.GetByIdAsync(1004, CancellationToken.None);

        order.Should().NotBeNull();
        order!.Sku.Should().Be("FAB-SILK-13");
        order.UnitPrice.Should().Be(145.00m);
    }

    [Fact]
    public async Task GetByIdAsync_UnknownId_ReturnsNull()
    {
        var order = await _repository.GetByIdAsync(9999, CancellationToken.None);

        order.Should().BeNull();
    }
}
