import Link from 'next/link';
import { listOrders } from '@/lib/api';

export default async function HomePage() {
  const orders = await listOrders();

  return (
    <>
      <h1 style={{ marginTop: 0 }}>Orders</h1>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr style={{ textAlign: 'left', color: '#8b929e', fontSize: '.8rem' }}>
            <th style={{ padding: '.5rem 0' }}>Order</th>
            <th>Customer</th>
            <th>SKU</th>
            <th style={{ textAlign: 'right' }}>Qty</th>
            <th style={{ textAlign: 'right' }}>Unit</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {orders.map((order) => (
            <tr key={order.id} style={{ borderTop: '1px solid #23262d' }}>
              <td style={{ padding: '.6rem 0' }}>
                <Link href={`/orders/${order.id}`} style={{ color: '#6ea8fe' }}>
                  #{order.id}
                </Link>
              </td>
              <td>{order.customer}</td>
              <td style={{ fontFamily: 'ui-monospace, monospace' }}>{order.sku}</td>
              <td style={{ textAlign: 'right' }}>{order.quantity}</td>
              <td style={{ textAlign: 'right' }}>{order.unitPrice.toFixed(2)}</td>
              <td>{order.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}
