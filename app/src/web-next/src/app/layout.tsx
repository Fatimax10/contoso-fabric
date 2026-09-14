import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Contoso Fabric',
  description: 'Demonstration storefront for the DevOps platform showcase.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body
        style={{
          fontFamily: 'system-ui, -apple-system, Segoe UI, sans-serif',
          margin: 0,
          background: '#0f1115',
          color: '#e6e8eb',
        }}
      >
        <header
          style={{
            padding: '1rem 2rem',
            borderBottom: '1px solid #23262d',
            display: 'flex',
            gap: '1rem',
            alignItems: 'baseline',
          }}
        >
          <strong style={{ fontSize: '1.1rem' }}>Contoso Fabric</strong>
          <span style={{ color: '#8b929e', fontSize: '.85rem' }}>DevOps showcase</span>
        </header>
        <main style={{ padding: '2rem', maxWidth: 900, margin: '0 auto' }}>{children}</main>
      </body>
    </html>
  );
}
