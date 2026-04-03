import Docker from 'dockerode';

// Connect to the Docker socket
const docker = new Docker({
  socketPath: '/var/run/docker.sock'
});

// List all containers (running + stopped)
export async function listContainers() {
  return docker.listContainers({ all: true });
}

// Get a specific container by ID
export function getContainer(id) {
  return docker.getContainer(id);
}
