# Velora Mobitech Optimization: Corporate Commute Route Planner

This project contains a comprehensive Vehicle Routing Optimization Engine for Corporate Commutes (solving DARPTW - Dial-A-Ride Problem with Time Windows), paired with a frontend Website and Mobile App visualization. 

## Full Project Flow
1. **Data Ingestion**: Raw operational data (employees, vehicles, priorities, metadata) is ingested via Excel files.
2. **Optimization Engine**: A powerful engine (featuring an Attention-based Reinforcement Learning approach) processes the geographic points and multiple constraints (time windows, capacity, premium status).
3. **Route Generation**: Generates the most optimal schedules maximizing served employees while minimizing travel costs and respecting drop-off deadlines.
4. **Output & Visualization**: The solution is exported to JSON and directly visualized on an intuitive web dashboard and mobile application.

## File Structure
- **`2613_Codebase/`**: The core source code for the project.
  - `App/`: Mobile application code.
  - `Website/`: Frontend web application for route visualization.
- **`2613_HackTestCases/`**: A suite of extensive edge-case datasets used to stress-test the routing engine.
- **`Experimental Approaches/`**: Contains theoretical research and our Reinforcement Learning (RL) solver experiments along with in-depth architecture documentation.
- **`2613_Apk.apk` / `2613_Apk.apk.zip`**: The compiled Android APK for testing the mobile experience.
- **`2613_Report.pdf`**: The full comprehensive report detailing the methodology, algorithms, and results.

## Hack Test Cases
To guarantee robust operations, the optimization engine was evaluated against numerous extreme scenarios located in `2613_HackTestCases`:
- **Stress Tests**: Large scale inputs (e.g., 120 employees, 40 vehicles).
- **Vehicle Anomalies**: Vehicles with zero capacity, zero speed, or unusually high speeds/costs.
- **Data Edge Cases**: Non-consecutive employee IDs and randomly shuffled rows.
- **Constraint Boundaries**: Intraday travel requirements and datasets structurally designed to have only one valid mathematical solution.
- **Geographic Realism**: Simulating routes on specific dense real-world coordinates (e.g., Silicon Valley Apple Park).

## Contact
- **LinkedIn Profile:** [Ruchir Sharma](https://www.linkedin.com/in/ruchir-sharma-243a10337/)
