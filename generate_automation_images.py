#!/usr/bin/env python3
"""
Generate automation shape images for Paketti Automation Curves.
This script recreates all automation curve images from scratch based on the
shape definitions in PakettiAutomationCurves.lua
"""

import math
import os
from PIL import Image, ImageDraw

# Image dimensions
WIDTH = 48
HEIGHT = 48

# Resolution for calculated curves (matches Lua code)
RESOLUTION = 16

# Colors (dark background, light curve - matching Renoise style)
BG_COLOR = (40, 40, 40)  # Dark gray background
CURVE_COLOR = (200, 200, 200)  # Light gray curve
GRID_COLOR = (60, 60, 60)  # Subtle grid lines

def calculate_shapes():
    """Calculate curved shapes matching the Lua implementation"""
    sin_up = []
    sin_down = []
    circ_br = []
    circ_tr = []
    circ_tl = []
    circ_bl = []
    cos_up = []
    cos_down = []
    bell_up = []
    bell_down = []
    scurve_up = []
    scurve_down = []
    bounce_up = []
    bounce_down = []
    
    for i in range(RESOLUTION):
        x = i / RESOLUTION
        
        # Sine curves
        sin_up.append((x, math.sin(x * math.pi)))
        sin_down.append((x, 1 - math.sin(x * math.pi)))
        
        # Circle quadrants
        circ_br.append((x, 1 - math.sqrt(1 - x * x)))
        circ_tr.append((x, math.sqrt(1 - x * x)))
        circ_tl.append((x, math.sqrt(2 * x - x * x)))
        circ_bl.append((x, 1 - math.sqrt(2 * x - x * x)))
        
        # Cosine curves
        cos_up.append((x, 1 - (0.5 * math.cos(x * math.pi) + 0.5)))
        cos_down.append((x, 0.5 * math.cos(x * math.pi) + 0.5))
        
        # Bell curve (Gaussian)
        gauss_x = (x - 0.5) * 4
        gauss_y = math.exp(-gauss_x * gauss_x / 2)
        bell_up.append((x, gauss_y))
        bell_down.append((x, 1 - gauss_y))
        
        # S-Curve (Sigmoid)
        sig_x = (x - 0.5) * 12
        sig_y = 1 / (1 + math.exp(-sig_x))
        scurve_up.append((x, sig_y))
        scurve_down.append((x, 1 - sig_y))
        
        # Bounce (decaying sine)
        bounce_decay = math.exp(-x * 3)
        bounce_osc = abs(math.sin(x * math.pi * 4))
        bounce_up.append((x, (1 - bounce_decay * bounce_osc)))
        bounce_down.append((x, bounce_decay * bounce_osc))
    
    # Add final points
    sin_up.append((0.99, 0))
    sin_down.append((0.99, 1))
    circ_br.append((0.99, 1))
    circ_tr.append((0.99, 0))
    circ_tl.append((0.99, 1))
    circ_bl.append((0.99, 0))
    cos_up.append((0.99, 1))
    cos_down.append((0.99, 0))
    bell_up.append((0.99, 0))
    bell_down.append((0.99, 1))
    scurve_up.append((0.99, 1))
    scurve_down.append((0.99, 0))
    bounce_up.append((0.99, 1))
    bounce_down.append((0.99, 0))
    
    return {
        'sinUp': sin_up,
        'sinDown': sin_down,
        'circBr': circ_br,
        'circTr': circ_tr,
        'circTl': circ_tl,
        'circBl': circ_bl,
        'cosUp': cos_up,
        'cosDown': cos_down,
        'bellUp': bell_up,
        'bellDown': bell_down,
        'sCurveUp': scurve_up,
        'sCurveDown': scurve_down,
        'bounceUp': bounce_up,
        'bounceDown': bounce_down
    }

def calculate_trapezoid():
    """Calculate trapezoid shapes matching the Lua implementation"""
    trap_up = [(0, 0), (1/3, 1/2)]
    trap_down = [(0, 1), (1/3, 1/2)]
    
    res_floor = math.floor(RESOLUTION / (3/2))
    for i in range(res_floor):
        p = (2/3) * i / res_floor
        x = 1/3 + p
        h2 = (3/2) - (9/4) * p
        y = (1/2) + (h2) * p + (((3/2) - h2) * p / 2)
        trap_up.append((x, y))
        trap_down.append((x, 1 - y))
    
    trap_up.append((0.99, 1))
    trap_down.append((0.99, 0))
    
    return {
        'trapUp': trap_up,
        'trapDown': trap_down
    }

def draw_curve(values, output_path):
    """Draw a curve from values array and save as PNG with anti-aliasing"""
    # Render at 4x resolution for smooth anti-aliasing, then scale down
    SCALE = 4
    render_width = WIDTH * SCALE
    render_height = HEIGHT * SCALE
    
    # Create high-resolution image with dark background
    img = Image.new('RGB', (render_width, render_height), BG_COLOR)
    draw = ImageDraw.Draw(img)
    
    # Draw subtle grid lines at high resolution
    for i in range(0, render_width, render_width // 4):
        draw.line([(i, 0), (i, render_height)], fill=GRID_COLOR, width=SCALE)
    for i in range(0, render_height, render_height // 4):
        draw.line([(0, i), (render_width, i)], fill=GRID_COLOR, width=SCALE)
    
    # Convert normalized values to high-resolution pixel coordinates
    # Y is inverted (0 at top, 1 at bottom in image coordinates)
    points = []
    for x, y in values:
        # Clamp y to 0-1 range (some curves like sawtooth can go outside)
        y_clamped = max(0, min(1, y))
        px = int(x * (render_width - 1))
        py = int((1 - y_clamped) * (render_height - 1))
        points.append((px, py))
    
    # Draw the curve at high resolution with thicker line for better visibility
    if len(points) > 1:
        draw.line(points, fill=CURVE_COLOR, width=SCALE * 2)
    
    # Scale down to final size with high-quality Lanczos resampling for smooth anti-aliasing
    img = img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    
    # Save image
    img.save(output_path, 'PNG')
    print(f"Generated: {output_path}")

def main():
    """Generate all automation shape images"""
    # Get script directory and create output path
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, 'images', 'automation_shapes')
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Calculate shapes
    calculated = calculate_shapes()
    trapezoid = calculate_trapezoid()
    
    # Define all shapes with their values and filenames
    shapes = {
        # Ramps (linear)
        'rampUp': {'values': [(0, 0), (0.99, 1)], 'filename': 'ramp-up.png'},
        'rampDown': {'values': [(0, 1), (0.99, 0)], 'filename': 'ramp-down.png'},
        
        # Circle quadrants
        'circTl': {'values': calculated['circTl'], 'filename': 'circ-tl.png'},
        'circTr': {'values': calculated['circTr'], 'filename': 'circ-tr.png'},
        
        # Squares
        'sqUp': {'values': [(0, 0), (0.5, 0), (0.51, 1), (0.99, 1)], 'filename': 'sq-up.png'},
        'sqDown': {'values': [(0, 1), (0.5, 1), (0.51, 0), (0.99, 0)], 'filename': 'sq-down.png'},
        
        # Trapezoids
        'trapUp': {'values': trapezoid['trapUp'], 'filename': 'trap-up.png'},
        'trapDown': {'values': trapezoid['trapDown'], 'filename': 'trap-down.png'},
        
        # Triangle/Vee
        'tri': {'values': [(0, 0), (0.5, 1), (0.99, 0)], 'filename': 'tri.png'},
        'vee': {'values': [(0, 1), (0.5, 0), (0.99, 1)], 'filename': 'vee.png'},
        
        # Circle quadrants (bottom)
        'circBl': {'values': calculated['circBl'], 'filename': 'circ-bl.png'},
        'circBr': {'values': calculated['circBr'], 'filename': 'circ-br.png'},
        
        # Sine
        'sinUp': {'values': calculated['sinUp'], 'filename': 'sin-up.png'},
        'sinDown': {'values': calculated['sinDown'], 'filename': 'sin-down.png'},
        
        # Stairs
        'stairUp': {'values': [(0, 0), (0.25, 0), (0.26, 0.25), (0.5, 0.25), (0.51, 0.5), (0.75, 0.5), (0.76, 0.75), (0.98, 0.75), (0.99, 1)], 'filename': 'stair-up.png'},
        'stairDown': {'values': [(0, 1), (0.25, 1), (0.26, 0.75), (0.5, 0.75), (0.51, 0.5), (0.75, 0.5), (0.76, 0.25), (0.98, 0.25), (0.99, 0)], 'filename': 'stair-down.png'},
        
        # Cosine
        'cosUp': {'values': calculated['cosUp'], 'filename': 'cos-up.png'},
        'cosDown': {'values': calculated['cosDown'], 'filename': 'cos-down.png'},
        
        # On/Off constants
        'on': {'values': [(0, 1), (0.99, 1)], 'filename': 'on.png'},
        'off': {'values': [(0, 0), (0.99, 0)], 'filename': 'off.png'},
        
        # Bell curve (Gaussian)
        'bellUp': {'values': calculated['bellUp'], 'filename': 'bell-up.png'},
        'bellDown': {'values': calculated['bellDown'], 'filename': 'bell-down.png'},
        
        # S-Curve (Sigmoid)
        'sCurveUp': {'values': calculated['sCurveUp'], 'filename': 'scurve-up.png'},
        'sCurveDown': {'values': calculated['sCurveDown'], 'filename': 'scurve-down.png'},
        
        # Bounce
        'bounceUp': {'values': calculated['bounceUp'], 'filename': 'bounce-up.png'},
        'bounceDown': {'values': calculated['bounceDown'], 'filename': 'bounce-down.png'},
        
        # Pulse variations (25%, 50%, 75% duty cycle)
        'pulse25': {'values': [(0, 0), (0.25, 0), (0.26, 1), (0.99, 1)], 'filename': 'pulse25.png'},
        'pulse50': {'values': [(0, 0), (0.5, 0), (0.51, 1), (0.99, 1)], 'filename': 'pulse50.png'},
        'pulse75': {'values': [(0, 0), (0.75, 0), (0.76, 1), (0.99, 1)], 'filename': 'pulse75.png'},
        
        # Random shapes - generate sample curves for visualization
        'randomSmooth': {'values': [(i/16, 0.3 + 0.4 * math.sin(i * 0.5)) for i in range(17)] + [(0.99, 0.5)], 'filename': 'random-smooth.png'},
        'randomStep': {'values': [(i/8, 0.2 + 0.6 * (i % 3) / 2) for i in range(9)] + [(0.99, 0.5)], 'filename': 'random-step.png'},
        
        # Sawtooth with overshoot
        'sawtoothUp': {'values': [(0, 0), (0.8, 1.1), (0.85, 0.95), (0.9, 1.02), (0.95, 0.99), (0.99, 1)], 'filename': 'sawtooth-up.png'},
        'sawtoothDown': {'values': [(0, 1), (0.8, -0.1), (0.85, 0.05), (0.9, -0.02), (0.95, 0.01), (0.99, 0)], 'filename': 'sawtooth-down.png'}
    }
    
    # Generate all images
    print(f"Generating automation shape images in: {output_dir}")
    print("=" * 60)
    
    for shape_name, shape_data in shapes.items():
        output_path = os.path.join(output_dir, shape_data['filename'])
        draw_curve(shape_data['values'], output_path)
    
    print("=" * 60)
    print(f"Successfully generated {len(shapes)} automation shape images!")

if __name__ == '__main__':
    main()
