TARGET="${1:-.}"

find "${TARGET}" -name Dockerfile | while read line; do
  dir="$(dirname "$line")"
  build_name="$(basename "${dir}")"
  docker build -t "${build_name}" "${dir}"
done
