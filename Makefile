# Edit this release and run "make release"
RELEASE=0.7.30-yelp2

UID:=`id -u`
GID:=`id -g`
DOCKER_RUN_LUCID:=docker run -t -v  $(CURDIR):/work:rw soatools_lucid_container
DOCKER_RUN_TRUSTY:=docker run -t -v  $(CURDIR):/work:rw soatools_trusty_container
DOCKER_RUN_CHRONOS:=docker run -t -i --link=chronos_itest_chronos:chronos -v  $(CURDIR):/work:rw chronos_itest/itest
DOCKER_QUICK_START:=docker run -t -i -v $(CURDIR):/work:rw soatools_lucid_container

.PHONY: all docs

all:

docs:
	cd src && tox -e docs

itest_lucid: package_lucid
	$(DOCKER_RUN_LUCID) /work/itest/ubuntu.sh

package_lucid: test build_lucid_docker
	$(DOCKER_RUN_LUCID) /bin/bash -c "cd src && dpkg-buildpackage -d && mv ../*.deb ../dist/"
	$(DOCKER_RUN_LUCID) chown -R $(UID):$(GID) /work

test:
	find . -name "*.pyc" -exec rm -rf {} \;
	cd src && tox -r
	cd src && tox -e marathon_integration

build_lucid_docker:
	[ -d dist ] || mkdir dist
	cd dockerfiles/lucid/ && docker build -t "soatools_lucid_container" .

itest_trusty: package_trusty
	$(DOCKER_RUN_TRUSTY) /work/itest/ubuntu.sh

package_trusty: test build_trusty_docker
	$(DOCKER_RUN_TRUSTY) /bin/bash -c "cd src && dpkg-buildpackage -d && mv ../*.deb ../dist/"
	$(DOCKER_RUN_TRUSTY) chown -R $(UID):$(GID) /work

build_trusty_docker:
	[ -d dist ] || mkdir dist
	cd dockerfiles/trusty/ && docker build -t "soatools_trusty_container" .

quick_start:
	$(DOCKER_QUICK_START) /bin/bash

clean:
	rm -rf dist/
	rm -rf src/.tox
	rm -rf src/paasta_tools.egg-info
	rm -rf src/build
	find . -name '*.pyc' -delete
	find . -name '__pycache__' -delete

#TODO: Move into fig
test_chronos: package_lucid setup_chronos_itest
	$(DOCKER_RUN_CHRONOS) /work/itest/chronos.sh
	make cleanup_chronos_itest

setup_chronos_itest: build_chronos_itest
	docker run -d --name=chronos_itest_zk chronos_itest/zookeeper
	docker run -d --name=chronos_itest_mesos --link chronos_itest_zk:zookeeper chronos_itest/mesos
	docker run -d --name=chronos_itest_chronos --link=chronos_itest_mesos:mesos --link=chronos_itest_zk:zookeeper chronos_itest/chronos

cleanup_chronos_itest:
	docker kill chronos_itest_zk
	docker kill chronos_itest_mesos
	docker kill chronos_itest_chronos
	docker rm chronos_itest_zk
	docker rm chronos_itest_mesos
	docker rm chronos_itest_chronos

build_chronos_itest: build_chronos_itest_zookeeper_docker build_chronos_itest_mesos_docker build_chronos_itest_chronos_docker build_chronos_itest_itest_docker

build_chronos_itest_zookeeper_docker:
	cd dockerfiles/itest/zookeeper/ && docker build -t "chronos_itest/zookeeper" .

build_chronos_itest_mesos_docker:
	cd dockerfiles/itest/mesos/ && docker build -t "chronos_itest/mesos" .

build_chronos_itest_chronos_docker:
	cd dockerfiles/itest/chronos/ && docker build -t "chronos_itest/chronos" .

build_chronos_itest_itest_docker:
	cd dockerfiles/itest/itest/ && docker build -t "chronos_itest/itest" .

VERSION = $(firstword $(subst -, ,$(RELEASE) ))
LAST_COMMIT_MSG = $(shell git log -1 --pretty=%B )
release:
	dch -v $(RELEASE) --changelog src/debian/changelog "$(LAST_COMMIT_MSG)"
	sed -i -e "s/version.*=.*/version        = '$(VERSION)',/" src/setup.py
	git tag --force v$(VERSION)
	echo "$(RELEASE) is tagged and changelog set."
	git diff
	echo 'git commit -a -m "Released $(RELEASE) via make release'
	echo 'git push --tags origin master'
