#!/usr/bin/env python3
"""
Script to generate docker-compose.yml from full_config.yaml
This script parses the dtn-ai-sidecars section and generates the appropriate services.
"""

import yaml
import os
import sys
from pathlib import Path

def load_config(config_path):
    """Load the full_config.yaml file"""
    try:
        with open(config_path, 'r') as file:
            return yaml.safe_load(file)
    except FileNotFoundError:
        print(f"Error: {config_path} not found")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error parsing YAML: {e}")
        sys.exit(1)

def generate_sidecar_services(sidecars_config):
    """Generate docker-compose services for dtn-ai sidecars"""
    services = {}
    
    for i, sidecar in enumerate(sidecars_config):
        for sidecar_name, sidecar_config in sidecar.items():
            service_name = sidecar_name
            
            # Generate environment variables
            env_vars = []
            if 'envs' in sidecar_config:
                for env_key, env_value in sidecar_config['envs'].items():
                    # Convert to uppercase and replace dots with underscores for docker-compose
                    env_var_name = env_key.upper().replace('.', '_')
                    env_vars.append(f"      - {env_var_name}=${{{env_value}}}")
            
            # Generate models configuration
            # Save models into a config file
            with open(f"docker-compose/{sidecar_name}-config.yaml", 'w') as f:
                yaml.dump({"models": sidecar_config['models']}, f, default_flow_style=False, indent=2)
            
            # Get the docker image from the new docker-image field
            docker_image = sidecar_config.get("docker-image", "latest")
            
            # Create the service configuration
            service_config = yaml.safe_load(f"""{service_name}:
    image: {docker_image}
    container_name: {service_name}
    ports:
      - "802{i+6}:8026"  # Dynamic port assignment
    environment:
      - PORT=8026
{chr(10).join(env_vars)}
    volumes:
      - ./{sidecar_name}-config.yaml:/app/config.yaml:ro
    restart: unless-stopped
    networks:
      - dtn-network
    healthcheck:
      test: ["CMD", "python", "-c", "import requests; requests.get('http://localhost:8026/health', timeout=5)"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    depends_on:
      - dtn-node""")
            
            services[service_name] = service_config[service_name]
    
    return services

def generate_docker_compose(base_content, out_compose, config, services):
    """Generate the complete docker-compose.yml file"""
    
    # Read the base docker-compose template
    with open(base_content, 'r') as f:
        template = yaml.safe_load(f)

    # Update the main dtn-network service with the docker-image from config
    if 'dtn-node' in template['services'] and 'dtn-network' in config:
        template['services']['dtn-node']['image'] = config['dtn-network'].get('docker-image', 'dtn-network-node:latest')

    for sk, sv in services.items():
        template['services'][sk] = sv
    
    # Write the complete docker-compose.yml
    with open(out_compose, 'w') as f:
        yaml.dump(template, f, default_flow_style=False, indent=2)
    
    print("Generated docker-compose.yml")

def main():
    """Main function"""
    config_path = "full_config.yaml"
    out_path = "./docker-compose/docker-compose.yml"
    base_content = './docker-compose.template'
    
    print("Loading configuration...")
    config = load_config(config_path)

    with open('docker-compose/dtn-network.yaml', 'w') as f:
        yaml.dump(config['dtn-network'], f, default_flow_style=False, indent=2)
    
    # Check if dtn-ai-sidecars section exists
    if 'dtn-ai-sidecars' not in config:
        print("No dtn-ai-sidecars configuration found in full_config.yaml")
        return
    
    print("Generating sidecar services...")
    services = generate_sidecar_services(config['dtn-ai-sidecars'])
    
    if not services:
        print("No sidecar services to generate")
        return
    
    print("Generating docker-compose.yml...")
    generate_docker_compose(base_content, out_path, config, services)
    
    print(f"Generated {len(services)} sidecar services:")
    for service_name in services.keys():
        print(f"  - {service_name}")
    
    print("\nTo start the services, run:")
    print("  docker-compose up -d")
    print("\nTo view logs:")
    print("  docker-compose logs -f")

if __name__ == "__main__":
    main() 