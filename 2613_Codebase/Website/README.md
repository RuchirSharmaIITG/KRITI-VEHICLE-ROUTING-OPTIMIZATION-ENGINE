# Running KRITI Locally

## Prerequisites
- g++, make, libboost
- Node.js (v18+) & npm

---

## 1. Backend (C++ Server — port 5555)

```bash
cd 2613_Backend
cd KRITI-Optimization

# Download Asio (required dependency)
wget https://sourceforge.net/projects/asio/files/asio/1.28.0%20%28Stable%29/asio-1.28.0.tar.gz/download -O asio.tar.gz
tar -xzf asio.tar.gz

# Build all solvers + server
make all

# Run the server
./server_app
```

Server will be live at `http://localhost:5555`.

---

## 2. Frontend (Next.js — port 3000)

In a **new terminal**:

```bash
cd 2613_frontend
cd Kriti-Software-Dev-main

npm install
```

Update `next.config.ts` to point to localhost instead of the remote IP:

```ts
destination: 'http://localhost:5555/:path*',
```

Then:

```bash
npm run dev
```

Frontend will be live at `http://localhost:3000`.

---

## Summary

| Service  | URL                    |
|----------|------------------------|
| Backend  | http://localhost:5555  |
| Frontend | http://localhost:3000  |
