# Pull the minimal Ubuntu image
FROM ubuntu
LABEL maintainer="Ajish"
# Install Nginx 
RUN apt-get -y update && apt-get -y install nginx

# Copy the Nginx config file
COPY default /etc/nginx/sites-available/default

# Expose the port for access
EXPOSE 80/tcp

# Run the Nginx server
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
