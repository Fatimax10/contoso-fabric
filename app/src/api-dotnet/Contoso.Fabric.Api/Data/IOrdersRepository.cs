using Contoso.Fabric.Api.Models;

namespace Contoso.Fabric.Api.Data;

public interface IOrdersRepository
{
    Task<IReadOnlyList<Order>> SearchAsync(string searchTerm, CancellationToken cancellationToken);

    Task<Order?> GetByIdAsync(int id, CancellationToken cancellationToken);
}
