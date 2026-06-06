"""
Covary Behavioral Data Analysis Pipeline
----------------------------------------
This script processes exported JSON data from the Covary application,
applies research data cleaning protocols, aggregates active/passive metrics,
calculates Spearman correlation matrices (with p-value significance tests),
conducts multi-day lag analyses, and outputs visualization plots.

Requirements:
    pip install pandas numpy scipy matplotlib seaborn
"""

import os
import json
import glob
import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from scipy.stats import spearmanr

# Configure plotting aesthetics for academic papers
sns.set_theme(style="whitegrid")
plt.rcParams.update({
    'font.size': 11,
    'axes.labelsize': 12,
    'axes.titlesize': 13,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'figure.titlesize': 14
})

def load_covary_data(json_path):
    """Loads and returns events data from the Covary JSON export file."""
    print(f"[1/6] Loading file: {json_path}")
    with open(json_path, 'r', encoding='utf-8') as f:
        payload = json.load(f)
    
    profile = payload.get('profile', {})
    events = payload.get('research_data', {}).get('events', [])
    print(f"Profile: Nickname={profile.get('nickname')}, UUID={profile.get('uuid')}")
    print(f"Loaded {len(events)} raw events.")
    return pd.DataFrame(events)

def clean_and_preprocess(df):
    """
    Applies thesis research cleaning protocols:
    - Discards active responses completed in under 1 second (spammer/accidental logs).
    - Cleans numerical data values.
    - Normalizes bedtime clock times past midnight.
    """
    print("[2/6] Cleaning and pre-processing events...")
    
    # 1. Parse timestamps
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    df['date'] = df['timestamp'].dt.normalize()
    df['hour'] = df['timestamp'].dt.hour
    
    # 2. Clean values: translate boolean and parse numeric strings
    def clean_val(row):
        val = str(row['value']).strip().lower()
        if val == 'true': return 1.0
        if val == 'false': return 0.0
        try:
            return float(val)
        except ValueError:
            return np.nan
            
    df['numeric_value'] = df.apply(clean_val, axis=1)
    df = df.dropna(subset=['numeric_value']).copy()

    # 3. Filter by response latency (spammer protection)
    # Exclude active responses (not triggered by system sensors) with latency < 1000ms
    active_mask = df['triggerSource'].isin(['manual', 'notification'])
    fast_log_mask = active_mask & (df['latencyMs'] < 1000) & (df['latencyMs'] > 0)
    cleaned_df = df[~fast_log_mask].copy()
    
    print(f"Discarded {len(df) - len(cleaned_df)} events with latency < 1000ms.")
    
    # 4. Continuous Bedtime Normalization
    # Check if we have bedtime events and normalize them
    bedtime_mask = cleaned_df['label'] == 'bedtime'
    if bedtime_mask.any():
        def normalize_bedtime(hour_float):
            # If bedtime is after noon (>= 12.0) or before noon (< 12.0)
            if hour_float < 12.0:
                return hour_float + 24.0 # Shift AM bedtime to continue past midnight (e.g. 01:30 -> 25.5)
            return hour_float
        
        # Apply bedtime shift
        cleaned_df.loc[bedtime_mask, 'numeric_value'] = cleaned_df.loc[bedtime_mask, 'numeric_value'].apply(normalize_bedtime)
        print("Applied continuous bedtime normalization (midnight wrap boundary shift).")
        
    return cleaned_df

def aggregate_daily_time_series(df):
    """
    Aggregates events into daily intervals based on metric categories:
    - Subjective Scales (Mood, Fatigue): Mean
    - Continuous Counters (Coffee, Meals): Sum
    - Passive daily metrics (Screen time, Steps): Max
    """
    print("[3/6] Aggregating daily time series...")
    
    # Separate metrics by aggregation strategies
    scales = df[df['category'].isin(['mood', 'productivity']) | df['label'].str.contains('quality')]
    counters = df[df['category'].isin(['nutrition', 'behavior', 'social'])]
    totals = df[df['category'].isin(['appUsage', 'health']) & ~df['label'].str.contains('quality')]
    
    # Aggregate
    daily_scales = scales.groupby(['date', 'label'])['numeric_value'].mean().unstack()
    daily_counters = counters.groupby(['date', 'label'])['numeric_value'].sum().unstack()
    daily_totals = totals.groupby(['date', 'label'])['numeric_value'].max().unstack()
    
    # Merge daily dataframes
    daily_df = pd.concat([daily_scales, daily_counters, daily_totals], axis=1).sort_index()
    print(f"Aggregated daily matrix dimensions: {daily_df.shape}")
    return daily_df

def calculate_correlations(daily_df, output_dir):
    """Computes daily Spearman's Rank correlations and builds a correlation heatmap."""
    print("[4/6] Computing Spearman correlation matrices...")
    
    # Drop rows that are completely empty
    cleaned_daily = daily_df.dropna(how='all')
    if len(cleaned_daily) < 3:
        print("Warning: Insufficient overlapping data points (< 3 days) to calculate correlations.")
        return
        
    # Calculate Spearman correlation coefficient and p-values
    corr_matrix, p_matrix = spearmanr(cleaned_daily, nan_policy='omit')
    
    # Handle single metric corner case
    if isinstance(corr_matrix, float):
        print("Only one metric found, skipping matrix plotting.")
        return
        
    corr_df = pd.DataFrame(corr_matrix, index=cleaned_daily.columns, columns=cleaned_daily.columns)
    p_df = pd.DataFrame(p_matrix, index=cleaned_daily.columns, columns=cleaned_daily.columns)
    
    # Save correlation matrices to csv
    corr_df.to_csv(os.path.join(output_dir, "spearman_correlations.csv"))
    p_df.to_csv(os.path.join(output_dir, "correlation_p_values.csv"))
    
    # Plot Heatmap
    plt.figure(figsize=(10, 8))
    mask = np.triu(np.ones_like(corr_df, dtype=bool)) # Half mask
    sns.heatmap(
        corr_df, 
        mask=mask, 
        annot=True, 
        fmt=".2f", 
        cmap="coolwarm", 
        vmin=-1, 
        vmax=1, 
        cbar_kws={'label': "Spearman Correlation ($\\rho$)"}
    )
    plt.title("Longitudinal Daily Spearman Correlation Matrix")
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, "spearman_heatmap.png"), dpi=300)
    plt.close()
    print("Saved correlation heatmap to disk.")

def calculate_lagged_relationships(daily_df, metric_a, metric_b, output_dir, max_lag=7):
    """Sweeps lags from 0 to max_lag and plots the resulting correlation curves."""
    print(f"[5/6] Calculating lagged relationships for: {metric_a} -> {metric_b}...")
    
    if metric_a not in daily_df.columns or metric_b not in daily_df.columns:
        print(f"Metrics '{metric_a}' or '{metric_b}' missing from data. Skipping lag sweep.")
        return
        
    lags = []
    rhos = []
    p_vals = []
    
    series_a = daily_df[metric_a]
    series_b = daily_df[metric_b]
    
    for k in range(max_lag + 1):
        # Shift Metric B forward by k days (T vs T+k)
        shifted_b = series_b.shift(-k)
        aligned = pd.concat([series_a, shifted_b], axis=1).dropna()
        
        if len(aligned) >= 5:
            rho, p = spearmanr(aligned.iloc[:, 0], aligned.iloc[:, 1])
            lags.append(k)
            rhos.append(rho)
            p_vals.append(p)
        else:
            lags.append(k)
            rhos.append(np.nan)
            p_vals.append(np.nan)
            
    lag_df = pd.DataFrame({'Lag_Days': lags, 'Spearman_Rho': rhos, 'p_value': p_vals})
    lag_df.to_csv(os.path.join(output_dir, f"lagged_{metric_a}_to_{metric_b}.csv"), index=False)
    
    # Plot Lag Curves
    plt.figure(figsize=(8, 5))
    plt.plot(lags, rhos, marker='o', linewidth=2, color='#1F77B4')
    plt.axhline(0, color='gray', linestyle='--')
    plt.xlabel(f"Lag k (Days) [{metric_a} at Day T -> {metric_b} at Day T+k]")
    plt.ylabel("Spearman Correlation ($\\rho$)")
    plt.title(f"Time-Lagged Correlation Sweep: {metric_a} predicting {metric_b}")
    plt.xticks(lags)
    plt.ylim(-1, 1)
    
    # Highlight significant points (p < 0.05)
    for i, p in enumerate(p_vals):
        if not np.isnan(p) and p < 0.05:
            plt.plot(lags[i], rhos[i], marker='o', color='red', markersize=8, label="Significant (p < 0.05)" if i==0 else "")
            
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, f"lag_sweep_{metric_a}_{metric_b}.png"), dpi=300)
    plt.close()
    print(f"Saved lag curve to disk for {metric_a} -> {metric_b}.")

def plot_circadian_rhythm(df, label, output_dir):
    """Aggregates and plots the average 24-hour circadian curve for a metric."""
    print(f"[6/6] Plotting circadian rhythm profile for: {label}...")
    
    metric_df = df[df['label'] == label].copy()
    if metric_df.empty:
        print(f"No events found for label '{label}'. Skipping circadian plot.")
        return
        
    unique_days = max(1, len(metric_df['date'].unique()))
    is_subjective = metric_df['category'].iloc[0] in ['mood', 'productivity']
    
    # Group by hour
    if is_subjective:
        # Subjective scales use mean (ignoring missing slots)
        hourly = metric_df.groupby('hour')['numeric_value'].mean()
    else:
        # Physical/digital metrics calculate the average total volume per hour across all unique days
        hourly = metric_df.groupby('hour')['numeric_value'].sum() / unique_days
        # Ensure all hours 0-23 are present, zero-fill if missing
        hourly = hourly.reindex(range(24), fill_value=0.0)
        
    # Plot circadian profile
    plt.figure(figsize=(9, 4.5))
    plt.plot(hourly.index, hourly.values, marker='s', color='#2CA02C', linewidth=2)
    plt.xlabel("Hour of the Day (0:00 - 23:00)")
    plt.ylabel("Average Value" if is_subjective else "Average Vol per Hour (Circadian Mean)")
    plt.title(f"Average 24-Hour Profile (Circadian Rhythm): {label}")
    plt.xticks(range(24))
    
    # Highlight typical bedtime hours
    plt.axvspan(23, 24, alpha=0.1, color='blue')
    plt.axvspan(0, 6, alpha=0.1, color='blue')
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, f"circadian_{label}.png"), dpi=300)
    plt.close()
    print(f"Saved circadian curve for {label} to disk.")

def main():
    # Identify target files in root or directories
    target_files = glob.glob("covary_all_*.json") + glob.glob("*.json")
    # Filter to files containing covary data
    covary_files = [f for f in target_files if 'covary' in f.lower() or 'research_data' in f.lower()]
    
    if not covary_files:
        print("No Covary JSON export files found in the current directory.")
        print("Please copy your export file (e.g. 'covary_all_xxx.json') into this folder and rerun.")
        return
        
    # Pick the most recent export file
    export_file = sorted(covary_files)[-1]
    
    # Setup output directory
    output_dir = "thesis_plots"
    os.makedirs(output_dir, exist_ok=True)
    print(f"Found export file: {export_file}. Writing plots to directory: {output_dir}/")
    
    # 1. Load
    df = load_covary_data(export_file)
    
    # 2. Preprocess
    cleaned_df = clean_and_preprocess(df)
    
    # 3. Daily Aggregate
    daily_df = aggregate_daily_time_series(cleaned_df)
    
    # 4. Heatmap
    calculate_correlations(daily_df, output_dir)
    
    # 5. Lag sweeps (example: correlating total screen time with next day mood/fatigue)
    calculate_lagged_relationships(daily_df, 'total_screen_time', 'mood', output_dir)
    calculate_lagged_relationships(daily_df, 'category_time:social', 'fatigue', output_dir)
    
    # 6. Circadian Profiles (example: mood and step segment peaks)
    plot_circadian_rhythm(cleaned_df, 'mood', output_dir)
    plot_circadian_rhythm(cleaned_df, 'total_screen_time', output_dir)
    
    print("\nData analysis pipeline completed successfully!")
    print(f"Check the directory '{output_dir}' to inspect the generated figures and CSV matrices.")

if __name__ == "__main__":
    main()
