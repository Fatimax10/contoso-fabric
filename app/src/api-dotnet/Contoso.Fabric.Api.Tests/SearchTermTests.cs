using Contoso.Fabric.Api.Search;
using FluentAssertions;
using Xunit;

namespace Contoso.Fabric.Api.Tests;

public sealed class SearchTermTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void TryNormalize_MissingTerm_Fails(string? raw)
    {
        var ok = SearchTerm.TryNormalize(raw, out var normalized, out var error);

        ok.Should().BeFalse();
        normalized.Should().BeEmpty();
        error.Should().Be("A search term is required.");
    }

    [Fact]
    public void TryNormalize_TooShort_Fails()
    {
        var ok = SearchTerm.TryNormalize("a", out _, out var error);

        ok.Should().BeFalse();
        error.Should().Contain("at least 2");
    }

    [Fact]
    public void TryNormalize_TooLong_Fails()
    {
        var ok = SearchTerm.TryNormalize(new string('x', SearchTerm.MaxLength + 1), out _, out var error);

        ok.Should().BeFalse();
        error.Should().Contain("64 characters or fewer");
    }

    [Fact]
    public void TryNormalize_AtMaxLength_Succeeds()
    {
        var ok = SearchTerm.TryNormalize(new string('x', SearchTerm.MaxLength), out var normalized, out _);

        ok.Should().BeTrue();
        normalized.Should().HaveLength(SearchTerm.MaxLength);
    }

    [Theory]
    [InlineData("  Northwind  ", "Northwind")]
    [InlineData("Northwind   Textiles", "Northwind Textiles")]
    [InlineData("\tFAB-LINEN-01\n", "FAB-LINEN-01")]
    public void TryNormalize_CollapsesWhitespace(string raw, string expected)
    {
        var ok = SearchTerm.TryNormalize(raw, out var normalized, out var error);

        ok.Should().BeTrue();
        error.Should().BeNull();
        normalized.Should().Be(expected);
    }
}
