#!/usr/bin/env bats

load helpers

@test "from-flags-order-verification" {
  run_buildah 1 from scratch -q
  check_options_flag_err "-q"

  run_buildah 1 from scratch --pull
  check_options_flag_err "--pull"

  run_buildah 1 from scratch --ulimit=1024
  check_options_flag_err "--ulimit=1024"

  run_buildah 1 from scratch --name container-name-irrelevant
  check_options_flag_err "--name"

  run_buildah 1 from scratch --cred="fake fake" --name small
  check_options_flag_err "--cred=fake fake"
}

@test "commit-to-from-elsewhere" {
  elsewhere=${TESTDIR}/elsewhere-img
  mkdir -p ${elsewhere}

  cid=$(buildah from --pull --signature-policy ${TESTSDIR}/policy.json scratch)
  buildah commit --signature-policy ${TESTSDIR}/policy.json $cid dir:${elsewhere}
  buildah rm $cid

  cid=$(buildah from --pull=false --signature-policy ${TESTSDIR}/policy.json dir:${elsewhere})
  buildah rm $cid
  [ "$cid" = elsewhere-img-working-container ]

  cid=$(buildah from --pull-always --signature-policy ${TESTSDIR}/policy.json dir:${elsewhere})
  buildah rm $cid
  [ "$cid" = `basename ${elsewhere}`-working-container ]

  cid=$(buildah from --pull --signature-policy ${TESTSDIR}/policy.json scratch)
  buildah commit --signature-policy ${TESTSDIR}/policy.json $cid dir:${elsewhere}
  buildah rm $cid

  cid=$(buildah from --pull=false --signature-policy ${TESTSDIR}/policy.json dir:${elsewhere})
  buildah rm $cid
  [ "$cid" = elsewhere-img-working-container ]

  cid=$(buildah from --pull-always --signature-policy ${TESTSDIR}/policy.json dir:${elsewhere})
  buildah rm $cid
  [ "$cid" = `basename ${elsewhere}`-working-container ]
}

@test "from-authenticate-cert" {

  mkdir -p ${TESTDIR}/auth
  # Create certificate via openssl
  openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${TESTDIR}/auth/domain.key -x509 -days 2 -out ${TESTDIR}/auth/domain.crt -subj "/C=US/ST=Foo/L=Bar/O=Red Hat, Inc./CN=localhost"
  # Skopeo and buildah both require *.cert file
  cp ${TESTDIR}/auth/domain.crt ${TESTDIR}/auth/domain.cert

  # Create a private registry that uses certificate and creds file
#  docker run -d -p 5000:5000 --name registry -v ${TESTDIR}/auth:${TESTDIR}/auth:Z -e REGISTRY_HTTP_TLS_CERTIFICATE=${TESTDIR}/auth/domain.crt -e REGISTRY_HTTP_TLS_KEY=${TESTDIR}/auth/domain.key registry:2

  # When more buildah auth is in place convert the below.
#  docker pull alpine
#  docker tag alpine localhost:5000/my-alpine
#  docker push localhost:5000/my-alpine

#  ctrid=$(buildah from localhost:5000/my-alpine --cert-dir ${TESTDIR}/auth)
#  buildah rm $ctrid
#  buildah rmi -f $(buildah --log-level=error images -q)

  # This should work
#  ctrid=$(buildah from localhost:5000/my-alpine --cert-dir ${TESTDIR}/auth  --tls-verify true)

  rm -rf ${TESTDIR}/auth

  # This should fail
  run ctrid=$(buildah from localhost:5000/my-alpine --cert-dir ${TESTDIR}/auth  --tls-verify true)
  [ "$status" -ne 0 ]

  # Clean up
#  docker rm -f $(docker ps --all -q)
#  docker rmi -f localhost:5000/my-alpine
#  docker rmi -f $(docker images -q)
#  buildah rm $ctrid
#  buildah rmi -f $(buildah --log-level=error images -q)
}

@test "from-authenticate-cert-and-creds" {
  mkdir -p  ${TESTDIR}/auth
  # Create creds and store in ${TESTDIR}/auth/htpasswd
#  docker run --entrypoint htpasswd registry:2 -Bbn testuser testpassword > ${TESTDIR}/auth/htpasswd
  # Create certificate via openssl
  openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${TESTDIR}/auth/domain.key -x509 -days 2 -out ${TESTDIR}/auth/domain.crt -subj "/C=US/ST=Foo/L=Bar/O=Red Hat, Inc./CN=localhost"
  # Skopeo and buildah both require *.cert file
  cp ${TESTDIR}/auth/domain.crt ${TESTDIR}/auth/domain.cert

  # Create a private registry that uses certificate and creds file
#  docker run -d -p 5000:5000 --name registry -v ${TESTDIR}/auth:${TESTDIR}/auth:Z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=${TESTDIR}/auth/htpasswd -e REGISTRY_HTTP_TLS_CERTIFICATE=${TESTDIR}/auth/domain.crt -e REGISTRY_HTTP_TLS_KEY=${TESTDIR}/auth/domain.key registry:2

  # When more buildah auth is in place convert the below.
#  docker pull=false alpine
#  docker login localhost:5000 --username testuser --password testpassword
#  docker tag alpine localhost:5000/my-alpine
#  docker push localhost:5000/my-alpine

#  ctrid=$(buildah from localhost:5000/my-alpine --cert-dir ${TESTDIR}/auth)
#  buildah rm $ctrid
#  buildah rmi -f $(buildah --log-level=error images -q)

#  docker logout localhost:5000

  # This should fail
  run ctrid=$(buildah from localhost:5000/my-alpine --cert-dir ${TESTDIR}/auth  --tls-verify true)
  [ "$status" -ne 0 ]

  # This should work
#  ctrid=$(buildah from localhost:5000/my-alpine --cert-dir ${TESTDIR}/auth  --tls-verify true --creds=testuser:testpassword)

  # Clean up
  rm -rf ${TESTDIR}/auth
#  docker rm -f $(docker ps --all -q)
#  docker rmi -f localhost:5000/my-alpine
#  docker rmi -f $(docker images -q)
#  buildah rm $ctrid
#  buildah rmi -f $(buildah --log-level=error images -q)
}

@test "from-tagged-image" {
  # Github #396: Make sure the container name starts with the correct image even when it's tagged.
  cid=$(buildah from --pull=false --signature-policy ${TESTSDIR}/policy.json scratch)
  buildah commit --signature-policy ${TESTSDIR}/policy.json "$cid" scratch2
  buildah rm $cid
  buildah tag scratch2 scratch3
  cid=$(buildah from --signature-policy ${TESTSDIR}/policy.json scratch3)
  [ "$cid" == scratch3-working-container ]
  buildah rm ${cid}
  buildah rmi scratch2 scratch3

  # Github https://github.com/containers/buildah/issues/396#issuecomment-360949396
  cid=$(buildah from --pull=true --signature-policy ${TESTSDIR}/policy.json alpine)
  buildah rm $cid
  buildah tag alpine alpine2
  cid=$(buildah from --signature-policy ${TESTSDIR}/policy.json localhost/alpine2)
  [ "$cid" == alpine2-working-container ]
  buildah rm ${cid}
  buildah rmi alpine alpine2

  cid=$(buildah from --pull=true --signature-policy ${TESTSDIR}/policy.json docker.io/alpine)
  buildah rm ${cid}
  buildah rmi docker.io/alpine

  cid=$(buildah from --pull=true --signature-policy ${TESTSDIR}/policy.json docker.io/alpine:latest)
  buildah rm ${cid}
  buildah rmi docker.io/alpine:latest

  cid=$(buildah from --pull=true --signature-policy ${TESTSDIR}/policy.json docker.io/centos:7)
  buildah rm ${cid}
  buildah rmi docker.io/centos:7

  cid=$(buildah from --pull=true --signature-policy ${TESTSDIR}/policy.json docker.io/centos:latest)
  buildah rm ${cid}
  buildah rmi docker.io/centos:latest
}

@test "from the following transports: docker-archive, oci-archive, and dir" {
  cid=$(buildah from --pull=true --signature-policy ${TESTSDIR}/policy.json alpine)
  buildah rm $cid
  buildah push --signature-policy ${TESTSDIR}/policy.json alpine docker-archive:docker-alp.tar:alpine
  buildah push --signature-policy ${TESTSDIR}/policy.json alpine oci-archive:oci-alp.tar:alpine
  buildah push --signature-policy ${TESTSDIR}/policy.json alpine dir:alp-dir
  buildah rmi alpine

  cid=$(buildah from --signature-policy ${TESTSDIR}/policy.json docker-archive:docker-alp.tar)
  [ "$cid" == alpine-working-container ]
  buildah rm ${cid}
  buildah rmi alpine
  rm -f docker-alp.tar

  cid=$(buildah from --signature-policy ${TESTSDIR}/policy.json oci-archive:oci-alp.tar)
  [ "$cid" == alpine-working-container ]
  buildah rm ${cid}
  buildah rmi alpine
  rm -f oci-alp.tar

  cid=$(buildah from --signature-policy ${TESTSDIR}/policy.json dir:alp-dir)
  [ "$cid" == alp-dir-working-container ]
  buildah rm ${cid}
  buildah rmi alp-dir
  rm -rf alp-dir
}

@test "from the following transports: docker-archive and oci-archive with no image reference" {
  cid=$(buildah from --pull=true --signature-policy ${TESTSDIR}/policy.json alpine)
  buildah rm $cid
  buildah push --signature-policy ${TESTSDIR}/policy.json alpine docker-archive:docker-alp.tar
  buildah push --signature-policy ${TESTSDIR}/policy.json alpine oci-archive:oci-alp.tar
  buildah rmi alpine

  cid=$(buildah from --signature-policy ${TESTSDIR}/policy.json docker-archive:docker-alp.tar)
  [ "$cid" == docker-archive-working-container ]
  buildah rm ${cid}
  buildah rmi -a
  rm -f docker-alp.tar

  cid=$(buildah from --signature-policy ${TESTSDIR}/policy.json oci-archive:oci-alp.tar)
  [ "$cid" == oci-archive-working-container ]
  buildah rm ${cid}
  buildah rmi -a
  rm -f oci-alp.tar
}

@test "from cpu-period test" {
  skip_if_chroot
  skip_if_rootless
  skip_if_no_runtime
  skip_if_cgroupsv2

  cid=$(buildah from --cpu-period=5000 --pull --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah --log-level=error run $cid cat /sys/fs/cgroup/cpu/cpu.cfs_period_us
  expect_output "5000"
  buildah rm $cid
}

@test "from cpu-quota test" {
  skip_if_chroot
  skip_if_rootless
  skip_if_no_runtime
  skip_if_cgroupsv2

  cid=$(buildah from --cpu-quota=5000 --pull=false --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah --log-level=error run $cid cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us
  expect_output "5000"
  buildah rm $cid
}

@test "from cpu-shares test" {
  skip_if_chroot
  skip_if_rootless
  skip_if_no_runtime
  skip_if_cgroupsv2

  cid=$(buildah from --cpu-shares=2 --pull --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah --log-level=error run $cid cat /sys/fs/cgroup/cpu/cpu.shares
  expect_output "2"
  buildah rm $cid
}

@test "from cpuset-cpus test" {
  skip_if_chroot
  skip_if_rootless
  skip_if_no_runtime
  skip_if_cgroupsv2 "cgroupsv2: fails with EPERM on writing cpuset.cpus"

  cid=$(buildah from --cpuset-cpus=0 --pull=false --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah --log-level=error run $cid cat /sys/fs/cgroup/cpuset/cpuset.cpus
  expect_output "0"
  buildah rm $cid
}

@test "from cpuset-mems test" {
  skip_if_chroot
  skip_if_rootless
  skip_if_no_runtime
  skip_if_cgroupsv2 "cgroupsv2: fails with EPERM on writing cpuset.mems"

  cid=$(buildah from --cpuset-mems=0 --pull --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah --log-level=error run $cid cat /sys/fs/cgroup/cpuset/cpuset.mems
  expect_output "0"
  buildah rm $cid
}

@test "from memory test" {
  skip_if_chroot
  skip_if_rootless

  cid=$(buildah from --memory=40m --pull=false --signature-policy ${TESTSDIR}/policy.json alpine)

  # Life is much more complicated under cgroups v2
  mpath='/sys/fs/cgroup/memory/memory.limit_in_bytes'
  if is_cgroupsv2; then
      mpath="/sys/fs/cgroup\$(awk -F: '{print \$3}' /proc/self/cgroup)/memory.max"
  fi
  run_buildah --log-level=error run $cid sh -c "cat $mpath"
  expect_output "41943040" "$mpath"
  buildah rm $cid
}

@test "from volume test" {
  skip_if_no_runtime

  cid=$(buildah from --volume=${TESTDIR}:/myvol --pull --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah --log-level=error run $cid -- cat /proc/mounts
  expect_output --substring " /myvol "
  buildah rm $cid
}

@test "from volume ro test" {
  skip_if_chroot
  skip_if_no_runtime

  cid=$(buildah from --volume=${TESTDIR}:/myvol:ro --pull=false --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah --log-level=error run $cid -- cat /proc/mounts
  expect_output --substring " /myvol "
  buildah rm $cid
}

@test "from shm-size test" {
  skip_if_chroot
  skip_if_no_runtime

  cid=$(buildah from --shm-size=80m --pull --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah --log-level=error run $cid -- df -h /dev/shm
  expect_output --substring " 80.0M "
  buildah rm $cid
}

@test "from add-host test" {
  skip_if_no_runtime

  cid=$(buildah from --add-host=localhost:127.0.0.1 --pull --signature-policy ${TESTSDIR}/policy.json alpine)
  run_buildah run $cid -- cat /etc/hosts
  expect_output --substring "127.0.0.1 +localhost"
  buildah rm $cid
}

@test "from name test" {
  container_name=mycontainer
  cid=$(buildah from --name=${container_name} --pull --signature-policy ${TESTSDIR}/policy.json alpine)
  buildah --log-level=error inspect --format '{{.Container}}' ${container_name}
  buildah rm $cid
}

@test "from cidfile test" {
  buildah from --cidfile output.cid --pull=false --signature-policy ${TESTSDIR}/policy.json alpine
  cid=$(cat output.cid)
  run_buildah --log-level=error containers -f id=${cid}
  buildah rm ${cid}
}

@test "from pull never" {
  run_buildah 1 from --signature-policy ${TESTSDIR}/policy.json --pull-never busybox
  echo "$output"
  expect_output --substring "no such image"

  run_buildah from --signature-policy ${TESTSDIR}/policy.json --pull=false busybox
  echo "$output"
  expect_output --substring "busybox-working-container"

  run_buildah from --signature-policy ${TESTSDIR}/policy.json --pull-never busybox
  echo "$output"
  expect_output --substring "busybox-working-container"

  buildah rmi --all --force
}

@test "from pull false no local image" {
  target=my-busybox
  run_buildah from --signature-policy ${TESTSDIR}/policy.json --pull=false busybox
  echo "$output"
  expect_output --substring "busybox-working-container"

  buildah rmi --all --force
}

@test "from with nonexistent authfile: fails" {
  run_buildah 1 from --authfile /no/such/file --pull --signature-policy ${TESTSDIR}/policy.json alpine
  expect_output "error checking authfile path /no/such/file: stat /no/such/file: no such file or directory"
}

@test "from --pull-always: emits 'Getting' even if image is cached" {
  run buildah pull --signature-policy ${TESTSDIR}/policy.json docker.io/busybox
  run_buildah from --signature-policy ${TESTSDIR}/policy.json --name busyboxc --pull-always docker.io/busybox
  expect_output --substring "Getting"
  buildah commit --signature-policy ${TESTSDIR}/policy.json busyboxc fakename-img
  run_buildah 1 from --signature-policy ${TESTSDIR}/policy.json --pull-always fakename-img
  run_buildah rm busyboxc
  run_buildah rmi fakename-img
}

@test "from --quiet: should not emit progress messages" {
  # Force a pull. Normally this would say 'Getting image ...' and other
  # progress messages. With --quiet, we should see only the container name.
  run_buildah '?' rmi busybox
  run_buildah from --signature-policy ${TESTSDIR}/policy.json --quiet docker.io/busybox
  expect_output "busybox-working-container"
}
