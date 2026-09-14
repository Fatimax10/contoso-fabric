# syntax=docker/dockerfile:1
#
# Build context is `app/src` (NOT this folder), because the API has a ProjectReference
# to ../../shared-lib. Build with:
#   docker build -f api-dotnet/Dockerfile -t contoso-fabric-api:dev app/src
#
# CF-SUP-030 (planted): the build stage below pins the MOVING tag `:latest` instead of a
# digest or an explicit version. Builds are therefore not reproducible - the same commit
# can produce a different image tomorrow - and a compromised upstream tag lands silently.
# Container scanning flags this. Do not fix it unless the task asks - see seeds/FINDINGS.md.

FROM mcr.microsoft.com/dotnet/sdk:latest AS build
WORKDIR /src

# Restore first, on manifests only, so the layer caches across source edits.
COPY Directory.Build.props ./
COPY shared-lib/Contoso.Fabric.SharedLib/Contoso.Fabric.SharedLib.csproj shared-lib/Contoso.Fabric.SharedLib/
COPY api-dotnet/Contoso.Fabric.Api/Contoso.Fabric.Api.csproj api-dotnet/Contoso.Fabric.Api/
RUN dotnet restore api-dotnet/Contoso.Fabric.Api/Contoso.Fabric.Api.csproj

COPY shared-lib/ shared-lib/
COPY api-dotnet/Contoso.Fabric.Api/ api-dotnet/Contoso.Fabric.Api/
RUN dotnet publish api-dotnet/Contoso.Fabric.Api/Contoso.Fabric.Api.csproj \
    --configuration Release \
    --no-restore \
    --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

ENV ASPNETCORE_URLS=http://+:8080 \
    DOTNET_EnableDiagnostics=0

COPY --from=build /app/publish ./

# $APP_UID is defined by the aspnet base image and resolves to a non-root account.
USER $APP_UID
EXPOSE 8080

# Liveness and readiness are declared in the Helm chart (app/deploy/helm) rather than here,
# so that Kubernetes owns the probe contract. GET /health is the endpoint.
ENTRYPOINT ["dotnet", "Contoso.Fabric.Api.dll"]
