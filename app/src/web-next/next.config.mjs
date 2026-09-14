/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  env: {
    CONTOSO_API_BASE_URL: process.env.CONTOSO_API_BASE_URL ?? 'http://contoso-fabric-api:8080',
  },
};

export default nextConfig;
