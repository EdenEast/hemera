# Initial Setup Kubernetes Smoke Test

Apply these manifests after `scripts/get-kubeconfig` succeeds and `kubectl get nodes` shows every Cluster Node as `Ready`.

```sh
kubectl apply -f k8s/smoke-test/namespace.yaml
kubectl apply -f k8s/smoke-test/pvc.yaml
kubectl apply -f k8s/smoke-test/app.yaml
kubectl apply -f k8s/smoke-test/ingress.yaml
```

Validate local-path storage:

```sh
kubectl -n hemera-smoke-test get pvc local-path-smoke-test
```

The PVC should become `Bound`.

Validate the sample app and k3s ServiceLB exposure:

```sh
kubectl -n hemera-smoke-test get deploy,pod,svc,ingress
```

The `whoami-loadbalancer` service should receive an external address from k3s ServiceLB. From the LAN, curl that address:

```sh
curl http://SERVICE_LB_ADDRESS/
```

Validate Traefik ingress after pointing `whoami.hemera.local` at the relevant LAN address:

```sh
curl -H 'Host: whoami.hemera.local' http://SERVICE_LB_ADDRESS/
```

Cleanup:

```sh
kubectl delete namespace hemera-smoke-test
```
