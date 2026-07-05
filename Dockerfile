# Next.js build for EasyPanel (Nixpacks not used — plain Dockerfile builder).
FROM node:20-slim

WORKDIR /app

# install all deps (dev deps needed for `next build`)
COPY package*.json ./
RUN npm ci

COPY . .

# NEXT_PUBLIC_* must exist at build time so Next inlines them into the client bundle.
# EasyPanel passes them via --build-arg.
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL \
    NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY \
    NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL \
    NEXT_TELEMETRY_DISABLED=1 \
    NODE_OPTIONS=--max-old-space-size=1536

RUN npm run build

ENV NODE_ENV=production
EXPOSE 3000
CMD ["npm", "start"]
