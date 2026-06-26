import sys
import json
import copy
import random
from math import radians, cos, sin, asin, sqrt
import pandas as pd
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim

if len(sys.argv) > 1:
    MASTER_FILE = sys.argv[1]
else:
    MASTER_FILE = input('ENTER THE DATASET Path (without quotes): ').strip()
    if not MASTER_FILE:
        print("Error: Dataset path is required.")
        sys.exit(1)

DEVICE = torch.device("cpu")

# load all data
employees_df = pd.read_excel(MASTER_FILE, sheet_name='employees')
vehicles_df = pd.read_excel(MASTER_FILE, sheet_name='vehicles')
baseline_df = pd.read_excel(MASTER_FILE, sheet_name='baseline')
metadata_df = pd.read_excel(MASTER_FILE, sheet_name='metadata')

employees_data = []
for _, row in employees_df.iterrows():
    employees_data.append({
        'id': row['employee_id'],
        'priority': row['priority'],
        'pickup_lat': row['pickup_lat'],
        'pickup_lng': row['pickup_lng'],
        'drop_lat': row['drop_lat'],
        'drop_lng': row['drop_lng'],
        'early_pickup': row['earliest_pickup'],
        'latest_drop': row['latest_drop'],
        'vehicle_pref': str(row['vehicle_preference']).strip().lower(),
        'sharing_pref': row['sharing_preference']
    })

vehicles_data = []
for _, row in vehicles_df.iterrows():
    vehicles_data.append({
        'id': row['vehicle_id'],
        'type': row['fuel_type'],
        'capacity': row['capacity'],
        'cost_per_km': row['cost_per_km'],
        'speed_kmph': row['avg_speed_kmph'],
        'current_lat': row['current_lat'],
        'current_lng': row['current_lng'],
        'available_from': row['available_from'],
        'category': str(row['category']).strip().lower()
    })

baseline_cost_map = dict(zip(baseline_df['employee_id'], baseline_df['baseline_cost']))
baseline_time_map = dict(zip(baseline_df['employee_id'], baseline_df['baseline_time_min']))

meta_dict = dict(zip(metadata_df['key'], metadata_df['value']))
weight_cost = float(meta_dict['objective_cost_weight'])
weight_time = float(meta_dict['objective_time_weight'])

priority_delays = {
    1: int(meta_dict['priority_1_max_delay_min']),
    2: int(meta_dict['priority_2_max_delay_min']),
    3: int(meta_dict['priority_3_max_delay_min']),
    4: int(meta_dict['priority_4_max_delay_min']),
    5: int(meta_dict['priority_5_max_delay_min'])
}

share_limits = {
    'single': 1,
    'double': 2,
    'triple': 3
}

# compute spherical distance
def haversine(lon1, lat1, lon2, lat2):
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    a = max(0.0, min(1.0, a))
    c = 2 * asin(sqrt(a)) 
    return c * 6371 

def time_to_min(time_val):
    if hasattr(time_val, 'hour') and hasattr(time_val, 'minute'):
        return time_val.hour * 60 + time_val.minute
    elif isinstance(time_val, str):
        parts = time_val.split(':')
        return int(parts[0]) * 60 + int(parts[1])
    else:
        parts = str(time_val).split(':')
        return int(parts[0]) * 60 + int(parts[1])

def min_to_time(minutes_val):
    return f"{int(minutes_val//60):02d}:{int(minutes_val%60):02d}"

nodes_list = []

for employee_idx, employee in enumerate(employees_data):
    early_mins = time_to_min(employee['early_pickup'])
    late_drop_mins = time_to_min(employee['latest_drop'])
    
    if late_drop_mins < early_mins:
        late_drop_mins += 1440
        
    nodes_list.append({
        'type': 'PICKUP', 'employee_idx': employee_idx, 'id': employee['id'], 
        'lat': employee['pickup_lat'], 'lng': employee['pickup_lng'],
        'early_pickup': early_mins, 
        'latest_pickup': early_mins + priority_delays[employee['priority']],
        'vehicle_pref': employee['vehicle_pref'], 'sharing_pref': employee['sharing_pref'], 'priority': employee['priority'],
        'abs_drop_deadline': late_drop_mins,
        'drop_lat': employee['drop_lat'], 'drop_lng': employee['drop_lng'] 
    })

for employee_idx, employee in enumerate(employees_data):
    early_mins = time_to_min(employee['early_pickup'])
    late_drop_mins = time_to_min(employee['latest_drop'])
    
    if late_drop_mins < early_mins:
        late_drop_mins += 1440

    nodes_list.append({
        'type': 'DROP', 'employee_idx': employee_idx, 'id': employee['id'], 
        'lat': employee['drop_lat'], 'lng': employee['drop_lng'],
        'early_pickup': early_mins, 
        'latest_pickup': late_drop_mins,
        'vehicle_pref': employee['vehicle_pref'], 'sharing_pref': employee['sharing_pref'], 'priority': employee['priority']
    })

# setup distance matrices
NUM_NODES = len(nodes_list)
DISTANCE_MATRIX = np.zeros((NUM_NODES, NUM_NODES))

for i in range(NUM_NODES):
    for j in range(NUM_NODES):
        if i != j:
            DISTANCE_MATRIX[i][j] = haversine(
                nodes_list[i]['lng'], nodes_list[i]['lat'],
                nodes_list[j]['lng'], nodes_list[j]['lat']
            )

NUM_VEHICLES = len(vehicles_data)
VEHICLE_START_DIST = np.zeros((NUM_VEHICLES, NUM_NODES))

for vehicle_idx in range(NUM_VEHICLES):
    for node_idx in range(NUM_NODES):
        VEHICLE_START_DIST[vehicle_idx][node_idx] = haversine(
            vehicles_data[vehicle_idx]['current_lng'], vehicles_data[vehicle_idx]['current_lat'],
            nodes_list[node_idx]['lng'], nodes_list[node_idx]['lat']
        )

class AttentionModel(nn.Module):
    def __init__(self, input_dim=8, hidden_dim=128):
        super(AttentionModel, self).__init__()
        self.embed = nn.Linear(input_dim, hidden_dim)
        self.context_embed = nn.Linear(4, hidden_dim)
        
        self.W_q = nn.Linear(hidden_dim, hidden_dim)
        self.W_k = nn.Linear(hidden_dim, hidden_dim)
        self.V = nn.Linear(hidden_dim, 1)

    def forward(self, static_features, dynamic_context, mask):
        embedded_nodes = self.embed(static_features)
        context_vec = self.context_embed(dynamic_context).unsqueeze(1)
        
        q = self.W_q(context_vec)      
        k = self.W_k(embedded_nodes)   
        
        scores = self.V(torch.tanh(q + k)).squeeze(-1)
        
        scores = scores.masked_fill(mask == 0, float('-1e9'))
        
        temperature = 1.5 
        probs = F.softmax(scores / temperature, dim=1)

        return probs

# define environment logic
class RideShareEnv:
    def __init__(self, nodes_data, vehicles):
        self.nodes_data = nodes_data
        self.vehicles = vehicles
        self.num_nodes = len(nodes_data)

        self.node_lats = np.array([n['lat'] for n in nodes_data])
        self.node_lngs = np.array([n['lng'] for n in nodes_data])
        self.node_early = np.array([n['early_pickup'] for n in nodes_data])
        self.node_late = np.array([n['latest_pickup'] for n in nodes_data])
        self.node_emp = np.array([n['employee_idx'] for n in nodes_data])
        
        lats = [n['lat'] for n in nodes_data]
        lngs = [n['lng'] for n in nodes_data]
        min_lat, max_lat = min(lats), max(lats)
        min_lng, max_lng = min(lngs), max(lngs)

        node_features = [] 
        for n in nodes_data:
            norm_lat = (n['lat'] - min_lat) / (max_lat - min_lat + 1e-6)
            norm_lng = (n['lng'] - min_lng) / (max_lng - min_lng + 1e-6)
            norm_early = n['early_pickup'] / 1440.0
            norm_late = n['latest_pickup'] / 1440.0
            is_pickup = 1.0 if n['type'] == 'PICKUP' else 0.0
            norm_priority = n['priority'] / 5.0
            is_premium = 1.0 if n['vehicle_pref'] == 'premium' else 0.0
            share_size = share_limits[n['sharing_pref']] / 3.0
            
            node_features.append([norm_lat, norm_lng, norm_early, norm_late, is_pickup, norm_priority, is_premium, share_size])
            
        self.static_tensor = torch.FloatTensor(node_features).unsqueeze(0)

    def get_mask(self, vehicle_idx, state, visited_mask, served_global):
        vehicle = self.vehicles[vehicle_idx]
        mask = torch.ones(self.num_nodes)
        mask = mask * (1 - visited_mask)
        
        for i in range(self.num_nodes):
            if mask[i] == 0: 
                continue
            
            node = self.nodes_data[i]
            employee_idx = node['employee_idx']
            
            if employee_idx in served_global: 
                mask[i] = 0
                continue

            if state['node_idx'] is None:
                distance = VEHICLE_START_DIST[vehicle_idx][i]
            else:
                distance = DISTANCE_MATRIX[state['node_idx']][i]

            travel_time_mins = (distance / vehicle['speed_kmph']) * 60
            actual_time = max(state['time'] + travel_time_mins, node['early_pickup'])

            if actual_time > node['latest_pickup']:
                mask[i] = 0
                continue

            if node['type'] == 'PICKUP':
                if employee_idx in state['onboard']: 
                    mask[i] = 0
                    continue

                if state['load'] >= vehicle['capacity']: 
                    mask[i] = 0
                    continue
                
                if node['vehicle_pref'] == 'premium' and vehicle['category'] != 'premium': 
                    mask[i] = 0
                    continue
                if node['vehicle_pref'] == 'normal' and vehicle['category'] != 'normal': 
                    mask[i] = 0
                    continue
                
                my_limit = share_limits[node['sharing_pref']] 
                current_limit = state['share_mode'] if state['load'] > 0 else 99
                if (state['load'] + 1) > current_limit: 
                    mask[i] = 0
                    continue
                if (state['load'] + 1) > my_limit: 
                    mask[i] = 0
                    continue

                drop_idx = node['employee_idx'] + len(employees_data)
                dist_to_drop = DISTANCE_MATRIX[i][drop_idx]
                time_to_drop = (dist_to_drop / vehicle['speed_kmph']) * 60

                if (actual_time + time_to_drop) > node['abs_drop_deadline']:
                    mask[i] = 0
                    continue
                    
                violation = False
                for onboard_employee_idx in state['onboard']:
                    onboard_drop_idx = onboard_employee_idx + len(employees_data)
                    dist_to_onboard_drop = DISTANCE_MATRIX[i][onboard_drop_idx]
                    time_to_onboard_drop = (dist_to_onboard_drop / vehicle['speed_kmph']) * 60
                    if (actual_time + time_to_onboard_drop) > nodes_list[onboard_drop_idx]['latest_pickup']:
                        violation = True
                        break
                
                if violation:
                    mask[i] = 0
                    continue

            elif node['type'] == 'DROP':
                if employee_idx not in state['onboard']:
                    mask[i] = 0
                    continue
        
        return mask

def solve_vrp_rl():
    vehicle_indices = list(range(len(vehicles_data)))
    env = RideShareEnv(nodes_list, vehicles_data) 
    model = AttentionModel(input_dim=8).to(DEVICE)
    optimizer = optim.Adam(model.parameters(), lr=1e-3)

    global_best_schedule = [] 
    global_served_indices = set() 
    
    best_cost_overall = float('inf')
    no_improve_counter = 0
    moving_avg_baseline = None

    print("Starting Active Search (RL Training)...")

    for episode in range(100000): 
        current_vehicle_order = sorted(vehicle_indices, key=lambda x: vehicles_data[x]['cost_per_km'])
        
        if random.random() < 0.2: 
            random_idx = random.randint(0, len(current_vehicle_order)-2)
            current_vehicle_order[random_idx], current_vehicle_order[random_idx+1] = current_vehicle_order[random_idx+1], current_vehicle_order[random_idx]
        
        episode_schedule = []
        episode_served = set()
        episode_total_cost = 0
        episode_total_lateness = 0
        episode_visited_mask = torch.zeros(1, env.num_nodes)
        episode_log_probs = []
        
        for vehicle_idx in current_vehicle_order:
            vehicle_data = vehicles_data[vehicle_idx]
            
            state = {
                'loc': (vehicle_data['current_lat'], vehicle_data['current_lng']),
                'node_idx': None,
                'time': time_to_min(vehicle_data['available_from']),
                'load': 0,
                'share_mode': 0,
                'onboard': set()
            }
            route_log = []
            
            while True:
                mask = env.get_mask(vehicle_idx, state, episode_visited_mask.squeeze(), episode_served)
                if mask.sum() == 0: 
                    break
                
                context_tensor = torch.FloatTensor([[
                    (state['loc'][0] - env.node_lats.min()) / (env.node_lats.max() - env.node_lats.min() + 1e-6), 
                    (state['loc'][1] - env.node_lngs.min()) / (env.node_lngs.max() - env.node_lngs.min() + 1e-6), 
                    state['time'] / 1440.0,
                    state['load'] / (vehicle_data['capacity'] + 1e-6)
                ]])
                
                probs = model(env.static_tensor, context_tensor, mask.unsqueeze(0))
                distribution = torch.distributions.Categorical(probs)
                action = distribution.sample()
                episode_log_probs.append(distribution.log_prob(action)) 
                
                node_idx = action.item()
                node = nodes_list[node_idx]
                
                if state['node_idx'] is None:
                    distance = VEHICLE_START_DIST[vehicle_idx][node_idx]
                else:
                    distance = DISTANCE_MATRIX[state['node_idx']][node_idx]

                travel_time_mins = (distance / vehicle_data['speed_kmph']) * 60
                
                arrival_time = max(state['time'] + travel_time_mins, node['early_pickup'])
                lateness_mins = max(0, arrival_time - node['latest_pickup'])
                episode_total_lateness += lateness_mins
                
                financial_cost = distance * vehicle_data['cost_per_km']
                
                route_log.append({
                    'action': node['type'], 'id': node['id'], 'time': arrival_time, 
                    'distance': distance, 'cost': financial_cost, 'loc': (node['lat'], node['lng']),
                    'lateness_mins': lateness_mins
                })
                
                episode_total_cost += financial_cost
                state['loc'] = (node['lat'], node['lng'])
                state['node_idx'] = node_idx
                state['time'] = arrival_time
                episode_visited_mask[0, node_idx] = 1
                
                if node['type'] == 'PICKUP':
                    state['load'] += 1
                    state['onboard'].add(node['employee_idx'])
                    my_limit = share_limits[node['sharing_pref']]
                    if state['load'] == 1:
                        state['share_mode'] = my_limit
                    else:
                        state['share_mode'] = min(state['share_mode'], my_limit)
                else:
                    state['load'] -= 1
                    state['onboard'].remove(node['employee_idx'])
                    episode_served.add(node['employee_idx'])
                    if state['load'] == 0: 
                        state['share_mode'] = 0

            episode_schedule.append({
                'vehicle_id': vehicle_data['id'],
                'stops': route_log,
                'total_dist': sum(stop_info['distance'] for stop_info in route_log),
                'total_time': route_log[-1]['time'] - time_to_min(vehicle_data['available_from']) if route_log else 0
            })

        unserved_penalty = 0
        for i, employee in enumerate(employees_data):
            if i not in episode_served:
                unserved_penalty += 10000000 
        
        reward = -1 * (episode_total_cost + unserved_penalty)
        
        if moving_avg_baseline is None:
            moving_avg_baseline = reward
            advantage = 0.0 
        else:
            advantage = reward - moving_avg_baseline
            moving_avg_baseline = 0.99 * moving_avg_baseline + 0.01 * reward
        
        if episode_log_probs: 
            loss = -advantage * torch.stack(episode_log_probs).sum()
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()
            
        current_served_count = len(episode_served)
        best_served_count = len(global_served_indices)
        
        # update best schedule
        if current_served_count > best_served_count:
            global_best_schedule = [{'vehicle_id': route_data['vehicle_id'], 'stops': [dict(stop_info) for stop_info in route_data['stops']], 'total_dist': route_data['total_dist'], 'total_time': route_data['total_time']} for route_data in episode_schedule]
            global_served_indices = set(episode_served)
            
        elif current_served_count == best_served_count:
            current_cost = sum(sum(stop_info['cost'] for stop_info in route_data['stops']) for route_data in episode_schedule)
            best_cost = sum(sum(stop_info['cost'] for stop_info in route_data['stops']) for route_data in global_best_schedule)
            
            if current_cost < best_cost:
                global_best_schedule = [{'vehicle_id': route_data['vehicle_id'], 'stops': [dict(stop_info) for stop_info in route_data['stops']], 'total_dist': route_data['total_dist'], 'total_time': route_data['total_time']} for route_data in episode_schedule]
                global_served_indices = set(episode_served)

        current_best_cost = sum(sum(stop_info['cost'] for stop_info in route_data['stops']) for route_data in global_best_schedule)
        
        if current_served_count > best_served_count:
            no_improve_counter = 0
            best_cost_overall = current_best_cost
        elif current_served_count == best_served_count and current_best_cost < best_cost_overall:
            best_cost_overall = current_best_cost
            no_improve_counter = 0
        else:
            no_improve_counter += 1
            
        if no_improve_counter >= 1000:
            print(f"Stopping early at episode {episode} - No improvement for 1000 episodes.")
            break

    return global_best_schedule, global_served_indices

schedule, served_indices = solve_vrp_rl()

print("\n" + "="*80)
print("FINAL SCHEDULE (RL-TRAINED)")
print("="*80)

total_financial_cost = 0
total_passenger_time = 0 
total_system_lateness = 0  
passenger_report = {}

for run in schedule:
    vehicle_id = run['vehicle_id']
    vehicle_data = next(v for v in vehicles_data if v['id'] == vehicle_id)
    
    print(f"\nVehicle: {vehicle_id} ({vehicle_data['type']}, Cap:{vehicle_data['capacity']}, Cost:{vehicle_data['cost_per_km']}/km)")
    print("-" * 90)
    print(f"{'ACTION':<12} {'WHO':<5} {'TIME':<8} {'DIST(km)':<10} {'COST':<8} {'LATE':<6} {'STATUS'}")
    
    run_cost = 0
    veh_onboard_tracker = {}

    for stop in run['stops']:
        time_str = min_to_time(stop['time'])
        lateness_val = stop.get('lateness_mins', 0)
        lateness_flag = f"+{int(lateness_val)}m" if lateness_val > 0 else "-"
        status_msg = ""
        
        if stop['action'] == 'PICKUP':
            veh_onboard_tracker[stop['id']] = stop['time']
            status_msg = "Picked up"
            
            passenger_report[stop['id']] = {
                'vehicle': vehicle_id,
                'pickup_time': time_str,
                'drop_time': 'TBD',
                'duration': 0
            }
            
        elif stop['action'] == 'DROP':
            if stop['id'] in veh_onboard_tracker:
                duration = stop['time'] - veh_onboard_tracker[stop['id']]
                total_passenger_time += duration
                status_msg = f"Dropped (Ride: {int(duration)}m)"
                
                if stop['id'] in passenger_report:
                    passenger_report[stop['id']]['drop_time'] = time_str
                    passenger_report[stop['id']]['duration'] = duration

        print(f"{stop['action']:<12} {stop['id']:<5} {time_str:<8} {stop['distance']:<8.2f} {stop['cost']:<8.2f} {lateness_flag:<6} {status_msg}")
        
        run_cost += stop['cost']
        total_system_lateness += lateness_val
    
    total_financial_cost += run_cost
    print("-" * 90)
    print(f"Vehicle Total Dist: {run['total_dist']:.2f} km | Vehicle Cost: {run_cost:.2f}")

print("\n" + "="*80)
print("PASSENGER REPORT: BASELINE VS OPTIMIZED TIME")
print("="*80)
print(f"{'ID':<5} | {'VEH':<5} | {'PICKUP':<8} | {'DROP':<8} | {'ACTUAL DUR':<12} | {'BASE DUR':<10} | {'TIME SAVED'}")
print("-" * 80)

sorted_passengers = sorted(passenger_report.keys())
for passenger_id in sorted_passengers:
    passenger_data = passenger_report[passenger_id]
    actual_duration = int(passenger_data['duration'])
    base_duration = baseline_time_map.get(passenger_id, 0)
    saved_time = base_duration - actual_duration
    print(f"{passenger_id:<5} | {passenger_data['vehicle']:<5} | {passenger_data['pickup_time']:<8} | {passenger_data['drop_time']:<8} | {str(actual_duration)+' min':<12} | {str(base_duration)+' min':<10} | {saved_time:+} min")

unserved_ids = [employee['id'] for i, employee in enumerate(employees_data) if i not in served_indices]
if unserved_ids:
    print("-" * 80)
    print(f"UNSERVED PASSENGERS: {unserved_ids}")

served_passenger_ids = [passenger_id for passenger_id, data in passenger_report.items() if data['drop_time'] != 'TBD']
total_baseline_cost = sum(baseline_cost_map.get(passenger_id, 0) for passenger_id in served_passenger_ids)
total_baseline_time = sum(baseline_time_map.get(passenger_id, 0) for passenger_id in served_passenger_ids)

cost_savings = total_baseline_cost - total_financial_cost
time_savings = total_baseline_time - total_passenger_time
final_objective_score = (total_financial_cost * weight_cost) + (total_passenger_time * weight_time)

print("\n" + "="*80)
print("FINAL ANALYSIS: BASELINE VS OPTIMIZED")
print("="*80)
print(f"{'METRIC':<25} | {'BASELINE':<12} | {'OPTIMIZED':<12} | {'SAVINGS (Δ)'}")
print("-" * 80)
print(f"{'Total Financial Cost':<25} | ₹{total_baseline_cost:<11.2f} | ₹{total_financial_cost:<11.2f} | {cost_savings:+.2f}")
print(f"{'Total Passenger Time':<25} | {total_baseline_time:<11.0f} | {total_passenger_time:<11.0f} | {time_savings:+.0f} mins")
print("-" * 80)
print(f"System Lateness Penalty: {total_system_lateness:.0f} mins")
print(f"FINAL SCORE (Obj Func):  {final_objective_score:.2f}")
print("="*80)

output_data = {
    'schedule': schedule,
    'passenger_report': passenger_report,
    'metrics': {
        'total_cost': total_financial_cost,
        'total_passenger_time': total_passenger_time,
        'baseline_cost': total_baseline_cost,
        'cost_savings': cost_savings,
        'time_savings': time_savings,
        'system_lateness': total_system_lateness,
        'final_score': final_objective_score
    }
}
with open('results.json', 'w') as f:
    json.dump(output_data, f, indent=4)
print("\nResults successfully exported to 'results.json' for frontend consumption.")