import Link from 'next/link';
import { getOrder } from '@/lib/api';

/**
 * CF-SEC-011: the `note` query parameter is written straight into the DOM via
 * dangerouslySetInnerHTML with no escaping, so `?note=<img src=x onerror=alert(1)>` executes.
 * Planted so CodeQL raises `js/xss`. Do not fix it unless the task asks - see seeds/FINDINGS.md.
 */
export default async function OrderDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ note?: string }>;
}) {
  const { id } = await params;
  const { note } = await searchParams;

  const order = await getOrder(Number(id));

  if (!order) {
    return (
      <>
        <h1>Order not found</h1>
        <Link href="/" style={{ color: '#6ea8fe' }}>
          Back to orders
        </Link>
      </>
    );
  }

  const lineTotal = order.quantity * order.unitPrice;

  return (
    <>
      <Link href="/" style={{ color: '#6ea8fe', fontSize: '.85rem' }}>
        &larr; Back to orders
      </Link>
      <h1 style={{ marginBottom: '.25rem' }}>Order #{order.id}</h1>
      <p style={{ color: '#8b929e', marginTop: 0 }}>
        {order.customer} &middot; {new Date(order.createdUtc).toLocaleDateString('en-GB')}
      </p>

      <dl style={{ display: 'grid', gridTemplateColumns: 'max-content 1fr', gap: '.5rem 1.5rem' }}>
        <dt style={{ color: '#8b929e' }}>SKU</dt>
        <dd style={{ margin: 0, fontFamily: 'ui-monospace, monospace' }}>{order.sku}</dd>
        <dt style={{ color: '#8b929e' }}>Quantity</dt>
        <dd style={{ margin: 0 }}>{order.quantity}</dd>
        <dt style={{ color: '#8b929e' }}>Unit price</dt>
        <dd style={{ margin: 0 }}>{order.unitPrice.toFixed(2)}</dd>
        <dt style={{ color: '#8b929e' }}>Line total</dt>
        <dd style={{ margin: 0 }}>{lineTotal.toFixed(2)}</dd>
        <dt style={{ color: '#8b929e' }}>Status</dt>
        <dd style={{ margin: 0 }}>{order.status}</dd>
      </dl>

      {note ? (
        <section
          style={{
            marginTop: '2rem',
            padding: '1rem',
            border: '1px solid #23262d',
            borderRadius: 6,
          }}
        >
          <h2 style={{ fontSize: '.9rem', color: '#8b929e', marginTop: 0 }}>Fulfilment note</h2>
          {/* CF-SEC-011: planted XSS sink. */}
          <div dangerouslySetInnerHTML={{ __html: note }} />
        </section>
      ) : null}
    </>
  );
}
