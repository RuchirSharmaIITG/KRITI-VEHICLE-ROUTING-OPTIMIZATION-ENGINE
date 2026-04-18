# VELORA — Smart Fleet Assignment & Route Optimizer

**Live at [kriti-software-dev.vercel.app](https://kriti-software-dev.vercel.app)**

VELORA is a full-stack web application that visualizes and analyzes optimized employee transportation routes. You upload an Excel file with employee locations, vehicle fleet data, and configuration preferences — the app sends it to a C++ optimization backend, gets the best routes back, and renders everything on interactive maps with real-time analytics, a live fleet dashboard, and per-employee satisfaction scoring.

Built with Next.js 16, React 19, Leaflet maps, a 3D globe landing page, and a cyberpunk-themed dark UI. The frontend is deployed on Vercel; the optimization backend runs on a remote C++ server.

---

## What It Does

Here's the short version: you have a company with employees scattered across a city and a fleet of vehicles. You need to figure out which vehicle picks up whom, in what order, and when — minimizing cost while keeping everyone happy (on time, in their preferred vehicle type, with their preferred sharing arrangement).

VELORA handles the full workflow:

1. You upload an Excel file containing employee data, vehicle fleet data, a baseline (for comparison), and metadata (configuration).
2. The app parses the Excel client-side, extracts the sheets into CSVs, and sends them to the C++ optimization backend.
3. The backend runs multiple optimization algorithms in parallel (ALNS, Branch-and-Cut, Heterogeneous DARP, GOD-VNS, and a Memetic Algorithm that combines their outputs).
4. The best solution comes back as a CSV of vehicle-employee assignments with pickup/drop times.
5. The frontend takes those assignments, fetches real road paths from OSRM (or uses Haversine distances if external maps are disabled), and renders everything across four views: an interactive route map, a fleet dashboard, an analytics panel, and a satisfaction scoring dashboard.

---

## Table of Contents

- [Live Demo](#live-demo)
- [Features](#features)
- [How the UI Works](#how-the-ui-works)
- [Project Structure](#project-structure)
- [Input Format](#input-format)
- [Running Locally](#running-locally)
- [Environment and Configuration](#environment-and-configuration)
- [How the Frontend Talks to the Backend](#how-the-frontend-talks-to-the-backend)
- [The Four Dashboard Views](#the-four-dashboard-views)
- [Satisfaction Scoring Engine](#satisfaction-scoring-engine)
- [Tech Stack](#tech-stack)
- [Troubleshooting](#troubleshooting)
- [Deployment](#deployment)

---

## Live Demo

The production app is deployed at **[kriti-software-dev.vercel.app](https://kriti-software-dev.vercel.app)**. Just visit the URL, upload your Excel file, pick an optimization level, and hit "Initialize Map."

---

## Features

- **3D Globe Landing Page** — An animated globe with simulated vehicle routes rendered using react-globe.gl and Three.js. It looks dramatic and sets the tone before you even upload anything.

- **Drag-and-Drop Excel Upload** — Accepts `.xlsx`, `.xls`, and `.csv` files. The app reads the file client-side using SheetJS, validates the sheets, and extracts vehicle metadata for the fleet manifest before optimization even begins.

- **Three Optimization Levels** — Ultra Fast (10s budget), Fast (20s), and Optimal (60s). This controls how long the backend's solvers are allowed to run. More time generally means better solutions.

- **Interactive 2D Route Map** — A Leaflet.js map that shows every vehicle's route with color-coded polylines, pickup markers (green), drop-off markers (red), and depot markers (gold). Click any vehicle in the sidebar to isolate its route.

- **Route Simulation** — Hit the play button on any vehicle card and watch a car icon animate along the actual road path, stop by stop. The simulation follows the OSRM road geometry, not straight lines.

- **Resizable Sidebar** — The left panel (vehicle list + control panel) can be dragged wider or narrower. Click the thin edge between the sidebar and the map to resize.

- **Live Fleet Dashboard** — A table view showing every vehicle (including unassigned ones from your input file), their passenger count, total distance, estimated duration, and propulsion type. Below it, an employee assignments table with pickup/drop times and total ride duration.

- **Analytics Panel** — Bar charts comparing baseline vs. optimized costs per vehicle, employee commute time comparisons, fleet utilization pie chart, compliance metrics (vehicle preference, sharing preference, time window adherence), and a violation log.

- **Satisfaction Dashboard** — A per-employee satisfaction scoring system that evaluates three dimensions: time window compliance, vehicle type preference, and sharing preference. Each employee gets a weighted score out of 5.0, visualized with radar charts, scatter plots, and distribution histograms.

- **CSV Export** — Download the optimized route assignments as a CSV file directly from the dashboard.

---

## How the UI Works

When you open the app, you see the landing page with the rotating 3D globe. Here's the flow:

**Step 1: Upload.** Click the upload card (or drag a file onto it). The app accepts Excel files. Once uploaded, you'll see a green checkmark with the filename and an optimization level dropdown.

**Step 2: Choose optimization level.** Three options: Ultra Fast (good for testing), Fast (balanced), and Optimal (best quality, takes longer). This controls the time budget the backend solvers get.

**Step 3: Initialize Map.** Click the button. The app transitions from the landing page to the dashboard view. Simultaneously, the ControlPanel component fires off the Excel data to the backend.

**Step 4: Wait for optimization.** You'll see status messages in the sidebar: "Reading Excel..." → "Optimizing (Backend)..." → "Requesting OSRM routes..." → "Ready." The backend typically takes 10–60 seconds depending on the optimization level and dataset size.

**Step 5: Explore.** Once results arrive, you can switch between four tabs in the top nav: Map View, Dashboard, Analytics, and Satisfaction. The sidebar shows vehicle cards that you can click to highlight specific routes on the map.

---

## Project Structure

```
Kriti-Software-Dev-main/
│
├── app/
│   ├── page.js                 # Main page — landing screen + dashboard layout
│   ├── layout.js               # Root layout (Inter font, metadata)
│   ├── globals.css             # Tailwind 4 import + CSS variables
│   ├── favicon.ico
│   └── api/
│       └── optimize/
│           └── route.js        # Server-side API route (Excel → CSV extraction)
│
├── components/
│   ├── ControlPanel.js         # The brain — file parsing, backend calls, route building,
│   │                           #   OSRM fetching, analytics computation, compliance checks
│   ├── MapBoard.js             # Leaflet map with route rendering + vehicle simulation
│   ├── CyberpunkGlobe.js       # 3D globe animation for the landing page
│   ├── ResultsPanel.js         # Sidebar vehicle cards with route stats
│   ├── VeloraAnalytics.js      # Analytics tab — charts, costs, compliance, violations
│   └── SatisfactionDashboard.js # Per-employee satisfaction scoring + visualizations
│
├── backend/
│   └── data/                   # Sample CSV data files (employees, vehicles, metadata, baseline)
│
├── public/                     # Static assets (SVGs, favicon)
├── package.json                # Dependencies and scripts
├── next.config.ts              # API proxy rewrite rules
├── postcss.config.mjs          # PostCSS config for Tailwind
└── eslint.config.mjs           # ESLint configuration
```

### What each component does

**`app/page.js`** (479 lines) — The root page. Manages the global app state: which view you're on (landing vs. dashboard), which tab is active, the uploaded file, map data, selected vehicle, simulation state, and sidebar width. Renders the landing page with the globe and upload card, or the full dashboard with the nav bar and four tab views.

**`components/ControlPanel.js`** (1,151 lines) — The heaviest component and the real workhorse. When a file is uploaded, it reads the Excel workbook, extracts employee/vehicle/metadata/baseline sheets, parses every row with flexible column-name matching (handles aliases like `pickup_lat`, `pickuplatitude`, `lat`, `latitude`), sends the CSVs to the backend, receives the optimized assignments, maps employee IDs to coordinates, fetches OSRM road paths for each vehicle route, computes analytics (cost savings, time savings, compliance rates, violations), and passes everything to the parent page.

**`components/MapBoard.js`** (604 lines) — Renders the Leaflet map. Shows pickup markers, drop-off markers, depot markers, and color-coded route polylines. When you select a vehicle, it highlights that route and dims the rest. The simulation feature animates a car icon along the route path by interpolating position along the polyline geometry.

**`components/CyberpunkGlobe.js`** (175 lines) — The landing page eye candy. Uses react-globe.gl to render a 3D Earth with animated arcs representing simulated vehicle routes. Cars (yellow dots) move along great-circle paths. Auto-rotates and uses a dark blue atmosphere.

**`components/ResultsPanel.js`** (120 lines) — The sidebar vehicle list. Shows a card for each active vehicle with distance, duration, passenger count, and a play button for route simulation. Click a card to select that vehicle on the map.

**`components/VeloraAnalytics.js`** (394 lines) — The Analytics tab. Renders a grid of stat cards (total score, employees, distance, cost savings), a bar chart comparing baseline vs. optimized cost per vehicle, an employee commute time comparison chart, a fleet utilization pie chart, compliance percentage bars (vehicle preference, sharing preference, time windows), and a violations table.

**`components/SatisfactionDashboard.js`** (675 lines) — The Satisfaction tab. Computes a per-employee satisfaction score based on three weighted dimensions: time compliance (45%), vehicle preference (30%), and sharing preference (25%). Visualizes results with a fleet-wide radar chart, score distribution histogram, priority-group analysis, a scatter plot of individual scores, and a detailed employee table with expandable rows showing the scoring breakdown.

---

## Input Format

The app expects an Excel file (`.xlsx`) with up to four sheets. The names are matched case-insensitively and with fuzzy matching (e.g., "Employees" or "employee" or "requests" all work).

### Sheet 1: `employees` (required)

| Column | Aliases accepted | Description | Example |
|--------|-----------------|-------------|---------|
| employee_id | id, employee | Unique employee ID | E01 |
| priority | priority | 1 (highest) to 5 (lowest) | 2 |
| pickup_lat | pickuplatitude, lat, latitude | Home latitude | 12.936 |
| pickup_lng | pickuplongitude, lng, longitude | Home longitude | 77.625 |
| drop_lat | droplatitude, officelat | Office latitude | 12.9716 |
| drop_lng | droplongitude, officelng | Office longitude | 77.5946 |
| earliest_pickup | pickup_start, start_time | Earliest acceptable pickup | 08:15 |
| latest_drop | drop_end, end_time | Latest acceptable arrival | 09:15 |
| vehicle_preference | vehicle_type, pref | "premium", "normal", or "any" | premium |
| sharing_preference | sharing | "single", "double", "triple", or "any" | single |

Time values can be either HH:MM strings or Excel serial numbers (like 0.354166). The app handles both.

### Sheet 2: `vehicles` (recommended)

| Column | Aliases accepted | Description | Example |
|--------|-----------------|-------------|---------|
| vehicle_id | id, vehicle | Unique vehicle ID | V01 |
| fuel_type | fuel, propulsion, engine | Fuel type | electric |
| vehicle_type | type, category, class | Vehicle category | 4W |
| capacity | seats, max_passengers | Maximum passengers | 3 |
| cost_per_km | cost, price_per_km | Operating cost per km | 10 |
| avg_speed_kmph | — | Average speed in km/h | 30 |
| current_lat | start_lat, lat | Vehicle depot latitude | 12.935 |
| current_lng | start_lng, lng | Vehicle depot longitude | 77.62 |
| available_from | start_time | When the vehicle is available | 08:00 |
| category | — | "normal" or "premium" | premium |

### Sheet 3: `metadata` (recommended)

A key-value configuration sheet:

| key | value | What it does |
|-----|-------|-------------|
| test_case_id | TC_02 | Identifies the test case |
| city | Bengaluru | City name (informational) |
| allow_external_maps | TRUE | Set FALSE to use Haversine instead of OSRM road distances |
| priority_1_max_delay_min | 5 | Minutes of allowed delay for priority 1 employees |
| priority_2_max_delay_min | 10 | Minutes of allowed delay for priority 2 |
| priority_3_max_delay_min | 15 | Minutes of allowed delay for priority 3 |
| priority_4_max_delay_min | 20 | Minutes of allowed delay for priority 4 |
| priority_5_max_delay_min | 30 | Minutes of allowed delay for priority 5 |
| objective_cost_weight | 0.65 | How much to prioritize cost (0–1) |
| objective_time_weight | 0.35 | How much to prioritize time (should sum to 1 with cost) |

### Sheet 4: `baseline` (optional, for analytics comparison)

| Column | Description | Example |
|--------|-------------|---------|
| employee_id | Employee ID | E01 |
| baseline_cost | Pre-optimization cost for this employee | 430 |
| baseline_time_min | Pre-optimization commute time in minutes | 45 |

If you include the baseline sheet, the Analytics tab will show cost/time savings compared to the old routing. Without it, those comparison charts will be empty.

---

## Running Locally

### Prerequisites

- **Node.js 18 or later** (check with `node --version`)
- **npm** (comes with Node.js)
- A working internet connection (the app calls the remote optimization backend and the OSRM routing API)



### Step 1: Install dependencies

```bash
npm install
```

This installs Next.js 16, React 19, Leaflet, Three.js, react-globe.gl, Recharts, Chart.js, SheetJS, Axios, Framer Motion, Tailwind CSS 4, and everything else. Takes about a minute.

### Step 2: Run the development server

```bash
npm run dev
```

You should see:

```
  ▲ Next.js 16.1.4
  - Local: http://localhost:3000
```

### Step 3: Open the app

Navigate to **http://localhost:3000** in your browser. You'll see the VELORA landing page with the 3D globe.

### Step 4: Upload and optimize

Upload your Excel file, pick an optimization level, and click "Initialize Map." The ControlPanel will send the data to the backend, and results should appear within 10–60 seconds.

### Production build (optional)

If you want to run the optimized production build:

```bash
npm run build
npm start
```

The production build is faster and uses less memory. It runs on port 3000 by default.

---

## Environment and Configuration

### Backend URL

The most important configuration is in `next.config.ts`. This is where the frontend knows where to send optimization requests:

```typescript
async rewrites() {
  return [
    {
      source: '/api/backend/:path*',
      destination: 'http://35.208.133.51:5555/:path*',
    },
  ]
}
```

When the frontend calls `/api/backend/upload`, Next.js rewrites it to `http://35.208.133.51:5555/upload` — that's the remote C++ optimization server. If you're running your own backend (from the KRITI-Optimization repo), change this IP to `http://localhost:5555` for local development:

```typescript
destination: 'http://localhost:5555/:path*',
```

### OSRM API

The frontend uses the public OSRM demo server for road routing:

```javascript
const OSRM_BASE_URL = "https://router.project-osrm.org/route/v1/driving";
```

This is a free service with rate limits. For large datasets, the metadata setting `allow_external_maps = FALSE` disables OSRM and uses Haversine (straight-line) distances instead. The routes will be less accurate but the app won't fail from rate limiting.

### API route (`/api/optimize`)

There's also a local Next.js API route at `app/api/optimize/route.js` that handles Excel-to-CSV conversion and saves files to `backend/data/`. This exists for development and local testing — the main optimization flow goes through the rewrite proxy to the C++ backend.

---

## How the Frontend Talks to the Backend

Understanding the data flow helps a lot with debugging. Here's exactly what happens:

1. **Excel is read client-side** using SheetJS. The ControlPanel component extracts the `employees`, `vehicles`, `metadata`, and `baseline` sheets and converts each to a CSV blob.

2. **CSVs are sent as multipart form data** to `/api/backend/upload` (which rewrites to the C++ server at port 5555). The optimization level is sent as a number: 10 (ultra fast), 20 (fast), or 60 (optimal) — this becomes the solver runtime budget in seconds.

3. **The C++ backend responds with JSON** containing results from multiple solvers. The frontend prefers the Memetic Algorithm's output (`results.mem.csv_vehicle`), falling back to ALNS (`results.ALNS.csv_vehicle`) if needed.

4. **The frontend parses the CSV response**, which has columns: `vehicle_id`, `category`, `employee_id`, `pickup_time`, `drop_time`. It matches each employee ID to the coordinates from the original Excel, groups stops by vehicle, sorts them by time, and prepends the vehicle depot as the starting point.

5. **OSRM routing** is called for each vehicle's sequence of waypoints to get the actual road geometry (the curvy lines you see on the map). If OSRM fails or is disabled, the route falls back to Haversine straight lines.

6. **Analytics are computed** entirely on the frontend: cost savings, time comparisons, compliance metrics, violation detection, satisfaction scores. This means you don't need the backend to be running to view analytics — only to generate new optimization results.

---

## The Four Dashboard Views

### Map View

The main view. On the left is the sidebar with the ControlPanel (stats, retry button, upload button) and the ResultsPanel (vehicle cards). On the right is the Leaflet map.

- **Green markers** are employee pickup locations (with employee ID in the popup).
- **Red markers** are drop-off locations (typically the office).
- **Gold markers** are vehicle depots.
- **Colored polylines** are the vehicle routes. Each vehicle gets a unique color from a rotating palette (cyan, purple, pink, yellow, green, red).
- Click a vehicle card to highlight just that route. Click "All Vehicle Routes" to show everything.
- Hit the play button on a vehicle card to simulate the route — a car icon animates along the path.

### Dashboard

A table-based view with two sections: the Live Fleet Manifest (all vehicles with their stats) and the Employee Assignments table (every employee with their assigned vehicle, pickup time, drop time, and total ride duration).

The fleet manifest includes vehicles from your input that didn't get assigned to any route — they show up with "N/A" for distance and passengers, so you can see your full fleet utilization at a glance.

### Analytics

The data-heavy view. Shows:

- **Summary cards** — Total optimization score, employees processed, fleet distance, and cost savings.
- **Per-vehicle cost comparison** — A bar chart with baseline cost (gray) vs. optimized cost (cyan) for each vehicle.
- **Employee commute times** — A chart comparing baseline vs. optimized travel time per employee.
- **Fleet utilization** — A pie chart showing occupied vs. unassigned vehicles.
- **Compliance metrics** — Three progress bars showing what percentage of employees had their vehicle preference, sharing preference, and time window constraints satisfied.
- **Violation log** — A table listing every constraint violation: which employee, what type (vehicle preference, sharing preference, time window), what was expected, and what actually happened.

### Satisfaction

A per-employee scoring system built entirely on the frontend. Every employee gets a score from 1.0 to 5.0 based on three weighted factors:

- **Time compliance (45%)** — Were they picked up and dropped off within their allowed window? Early arrivals are fine; late arrivals degrade the score based on severity.
- **Vehicle preference (30%)** — Did they get the vehicle type they requested? Requesting premium and getting normal scores poorly.
- **Sharing preference (25%)** — Did the maximum occupancy during their ride respect their sharing preference? A "single" rider sharing with 3 others scores badly.

This tab shows a fleet-wide radar chart, a score distribution histogram, per-priority analysis, a scatter plot mapping individual employees by score, and an expandable table with the full scoring breakdown for every employee.

---

## Satisfaction Scoring Engine

The satisfaction scoring is worth explaining in detail because it's more nuanced than a simple pass/fail. It lives in `SatisfactionDashboard.js` and uses these models:

**Time scoring** uses a 4-zone model for drop-off timing:
- Zone A (in window): Score 4.60–5.00. You arrived on time or a bit early.
- Zone B (mild late, ≤5 min): Score scales down from ~4.0 to ~3.8. Slightly late.
- Zone C (notable late, 5–15 min): Score scales down from ~3.0 to ~2.4. Noticeably late.
- Zone D (severe, >15 min): Fixed score of 1.00. Unacceptably late.

**Sharing scoring** uses a step function:
- 0 excess passengers beyond preference: 5.00 (Excellent)
- 1 excess passenger: 1.71 (Poor)
- 2+ excess passengers: 1.00 (Critical)

**Vehicle scoring** uses an expectation-gradient:
- Got what you asked for (or asked for "any"): 5.00
- Normal employee gets premium: 5.00 (upgrade is fine)
- Premium employee gets normal: 2.00 (downgrade hurts)

The weighted formula: `Score = 0.45 × time_score + 0.30 × vehicle_score + 0.25 × sharing_score`

---

## Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Next.js (App Router) | 16.1.4 |
| UI Library | React | 19.2.3 |
| Styling | Tailwind CSS | 4 |
| Map Rendering | Leaflet + React-Leaflet | 1.9.4 / 5.0.0 |
| 3D Globe | react-globe.gl + Three.js | 2.37.0 / 0.182.0 |
| Charts | Recharts + Chart.js | 3.7.0 / 4.5.1 |
| Animations | Framer Motion | 12.29.0 |
| Icons | Lucide React | 0.562.0 |
| Excel Parsing | SheetJS (xlsx) | 0.18.5 |
| HTTP Client | Axios | 1.13.5 |
| Font | Inter (Google Fonts via next/font) | — |
| Deployment | Vercel | — |
| Backend | C++ (Crow framework, remote server) | — |
| Road Routing | OSRM public API | — |

---

## Troubleshooting

**The optimization hangs at "Optimizing (Backend)..."**

The most likely cause is the C++ backend being unreachable. The frontend proxies requests to `http://35.208.133.51:5555`. If that server is down, the request will time out. Check if the server is running by visiting `http://35.208.133.51:5555` directly. If you're running your own backend, make sure you've updated `next.config.ts` to point to `localhost:5555`.

**Routes show as straight lines instead of following roads**

This happens when OSRM fails. The public OSRM server at `router.project-osrm.org` has rate limits. With large datasets (50+ employees), you'll hit those limits. The app falls back to Haversine (straight-line) distances automatically. If your metadata has `allow_external_maps` set to `FALSE`, OSRM is skipped entirely and straight lines are intentional.

**The map is blank or all markers are at 0,0**

Your employee coordinates might be in the wrong columns. The column matcher is flexible but not magic — make sure your latitude/longitude columns have names close to `pickup_lat`, `pickup_lng`, `drop_lat`, `drop_lng` (or the aliases listed in the Input Format section). Check the browser console for parsing errors.

**"Missing 'Employees' sheet" error**

The app couldn't find a sheet named `employees`, `employee`, or `request` in your Excel file. Open your file and check that you have a sheet whose name contains the word "employee" (case doesn't matter).

**Analytics show 0% cost savings**

You probably don't have a `baseline` sheet in your Excel file. Without baseline data, the app has nothing to compare against. Add a sheet with columns `employee_id`, `baseline_cost`, and `baseline_time_min`.

**Satisfaction tab shows "Fetching data" spinner forever**

The satisfaction engine needs route data from the optimization to compute scores. If the backend call failed, there's no data to score. Fix the backend connection first, then the satisfaction tab will populate automatically.

**Globe doesn't render on the landing page**

react-globe.gl requires WebGL. If you're in a browser that doesn't support WebGL (or in an iframe that blocks it), the globe won't appear. You'll see a black background instead. The rest of the app works fine without it.

**Port 3000 is already in use**

Some other app is using that port. Either stop it or run Next.js on a different port:

```bash
npm run dev -- -p 3001
```

---

## Deployment

### Vercel (recommended)

The app is already configured for Vercel deployment. Just connect your GitHub repo to Vercel and it will build and deploy automatically on every push.

Key thing to note: the `next.config.ts` rewrites proxy API calls to the remote C++ backend. This means the optimization backend must be publicly accessible from Vercel's servers. If your backend is behind a firewall, the proxy won't work.

### Self-hosted

If you want to host it yourself:

```bash
npm run build
npm start
```

The production server runs on port 3000 by default. Set `PORT` in your environment to change it. You'll need to ensure the backend URL in `next.config.ts` is reachable from wherever you deploy.

### Connecting your own backend

If you have the KRITI-Optimization C++ backend running somewhere, just update `next.config.ts`:

```typescript
const nextConfig: NextConfig = {
  async rewrites() {
    return [
      {
        source: '/api/backend/:path*',
        destination: 'http://YOUR_BACKEND_IP:5555/:path*',
      },
    ]
  },
};
```

Rebuild and redeploy. The frontend doesn't care where the backend lives — as long as it speaks the same CSV format on the `/upload` endpoint, everything works.

---

## Contributing

The codebase is organized so that each component handles one concern. If you want to add features:

- New chart or metric? Add it to `VeloraAnalytics.js` (uses Recharts).
- New satisfaction dimension? Edit the scoring engine in `SatisfactionDashboard.js`.
- New map feature? Work in `MapBoard.js` (uses React-Leaflet).
- New data source or column format? The flexible column matching is in `ControlPanel.js` — look for the `findValue()` function.
- New API integration? Add rewrite rules in `next.config.ts` and call them from `ControlPanel.js`.

---

## License

Developed for the Kriti Optimization Challenge. Check with the repository owner for licensing details.
