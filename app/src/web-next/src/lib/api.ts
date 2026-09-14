export interface Order {
  id: number;
  customer: string;
  sku: string;
  quantity: number;
  unitPrice: number;
  status: string;
  createdUtc: string;
}

const baseUrl = process.env.CONTOSO_API_BASE_URL ?? 'http://contoso-fabric-api:8080';

/** Seed data used whenever the API is unreachable, so the storefront still renders. */
const fallbackOrders: Order[] = [
  {
    id: 1001,
    customer: 'Northwind Textiles',
    sku: 'FAB-LINEN-01',
    quantity: 12,
    unitPrice: 24.5,
    status: 'Shipped',
    createdUtc: '2026-01-04T09:30:00Z',
  },
  {
    id: 1002,
    customer: 'Aurora Interiors',
    sku: 'FAB-VELVET-07',
    quantity: 4,
    unitPrice: 61.0,
    status: 'Processing',
    createdUtc: '2026-01-07T09:30:00Z',
  },
  {
    id: 1004,
    customer: 'Meridian Studio',
    sku: 'FAB-SILK-13',
    quantity: 2,
    unitPrice: 145.0,
    status: 'Pending',
    createdUtc: '2026-01-18T09:30:00Z',
  },
];

async function getJson<T>(path: string): Promise<T | null> {
  try {
    const response = await fetch(`${baseUrl}${path}`, { cache: 'no-store' });
    if (!response.ok) {
      return null;
    }
    return (await response.json()) as T;
  } catch {
    return null;
  }
}

export async function searchOrders(term: string): Promise<Order[]> {
  const results = await getJson<Order[]>(`/orders/search?q=${encodeURIComponent(term)}`);
  if (results) {
    return results;
  }

  const needle = term.toLowerCase();
  return fallbackOrders.filter(
    (o) => o.customer.toLowerCase().includes(needle) || o.sku.toLowerCase().includes(needle),
  );
}

export async function getOrder(id: number): Promise<Order | null> {
  const order = await getJson<Order>(`/orders/${id}`);
  return order ?? fallbackOrders.find((o) => o.id === id) ?? null;
}

export async function listOrders(): Promise<Order[]> {
  return (await getJson<Order[]>('/orders/search?q=FAB')) ?? fallbackOrders;
}
