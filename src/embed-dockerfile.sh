a=$(tar cz "mok-centos-7$1" | base64 | sed 's/$/\\/')
sed -r '/mok-centos-7-tarball-start/, /mok-centos-7-tarball-end/ c \
  #mok-centos-7-tarball-start \
  cat <<'EnD' | base64 -d | tar xz -C "${_BI[dockerbuildtmpdir]}" \
'"$a"'
EnD\
  #mok-centos-7-tarball-end' src/buildimage.sh >src/buildimage.deploy
