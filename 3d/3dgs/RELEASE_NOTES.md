# 3DGS v1 runtime dependencies

Verified upstream binaries, redistributed unchanged; no source recompilation.

- PyCOLMAP 4.2.1 CPU: CPython 3.13, Linux amd64, manylinux_2_28. Depends on the consuming environment's NumPy.
- Brush 0.3.0: official Linux amd64 executable archive; training requires a working Vulkan device supplied by the deployment environment.
- Vulkan Loader 1.4.328.1-1.el10: generic Rocky Linux 10 distribution RPM, without a vendor ICD or device driver.

`SOURCE_MANIFEST.json` records original URLs, versions, hashes and embedded license locations. `SHA256SUMS` covers the three original distribution files. PyCOLMAP's COPYING.txt, Brush's LICENSE and the RPM's packaged license information are retained in their original distributions.

No model weights, device drivers, training datasets or generated PLY files are included. No PyTorch/CUDA ABI requirement is imposed by these assets. The consuming ComfyUI image still has its own hardware and base-environment requirements.

Assets under this version must not be replaced. Publish a new release version when their content changes.
