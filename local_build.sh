docker buildx build --load -t mobufan/fan-nginx \
    --cache-from "type=local,src=/tmp/.buildx-cache" \
    --cache-to "type=local,dest=/tmp/.buildx-cache" \
    --platform "linux/amd64" . 


