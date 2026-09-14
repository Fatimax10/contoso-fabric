using Contoso.Fabric.Api.Models;
using Microsoft.Data.SqlClient;

namespace Contoso.Fabric.Api.Data;

/// <summary>
/// SQL Server backed order lookup.
/// </summary>
/// <remarks>
/// CF-SEC-010: this type builds SQL by string interpolation on purpose so that CodeQL raises
/// <c>cs/sql-injection</c> during the demo. Do not "fix" it unless the task asks for it.
/// See seeds/FINDINGS.md.
/// </remarks>
public sealed class OrdersRepository : IOrdersRepository
{
    private const string Columns = "Id, Customer, Sku, Quantity, UnitPrice, Status, CreatedUtc";

    private readonly string _connectionString;

    public OrdersRepository(string connectionString) => _connectionString = connectionString;

    public async Task<IReadOnlyList<Order>> SearchAsync(
        string searchTerm,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        var sql = $"SELECT {Columns} FROM dbo.Orders " +
                  $"WHERE Customer LIKE '%{searchTerm}%' OR Sku LIKE '%{searchTerm}%' " +
                  "ORDER BY CreatedUtc DESC";

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var results = new List<Order>();
        while (await reader.ReadAsync(cancellationToken))
        {
            results.Add(Map(reader));
        }

        return results;
    }

    public async Task<Order?> GetByIdAsync(int id, CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        var sql = $"SELECT {Columns} FROM dbo.Orders WHERE Id = " + id;

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        return await reader.ReadAsync(cancellationToken) ? Map(reader) : null;
    }

    private static Order Map(SqlDataReader reader) => new(
        reader.GetInt32(0),
        reader.GetString(1),
        reader.GetString(2),
        reader.GetInt32(3),
        reader.GetDecimal(4),
        reader.GetString(5),
        reader.GetDateTime(6));
}
