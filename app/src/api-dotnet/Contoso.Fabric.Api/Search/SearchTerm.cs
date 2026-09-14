namespace Contoso.Fabric.Api.Search;

/// <summary>Normalisation and validation rules for the order search term.</summary>
public static class SearchTerm
{
    public const int MaxLength = 64;
    public const int MinLength = 2;

    /// <summary>
    /// Trims and collapses internal whitespace, then enforces the length bounds.
    /// </summary>
    /// <returns><c>true</c> when <paramref name="normalized"/> is safe to use.</returns>
    public static bool TryNormalize(
        string? raw,
        out string normalized,
        out string? error)
    {
        normalized = string.Empty;
        error = null;

        if (string.IsNullOrWhiteSpace(raw))
        {
            error = "A search term is required.";
            return false;
        }

        normalized = string.Join(' ', raw.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));

        if (normalized.Length < MinLength)
        {
            error = $"Search term must be at least {MinLength} characters.";
            normalized = string.Empty;
            return false;
        }

        if (normalized.Length > MaxLength)
        {
            error = $"Search term must be {MaxLength} characters or fewer.";
            normalized = string.Empty;
            return false;
        }

        return true;
    }
}
