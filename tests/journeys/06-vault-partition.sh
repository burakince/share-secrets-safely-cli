#!/bin/bash

set -eu
exe=${1:?First argument is the executable under test}

root="$(cd "${0%/*}" && pwd)"
exe="$root/../../$exe"
# shellcheck source=./tests/gpg-helpers.sh
source "$root/../gpg-helpers.sh"

WITH_FAILURE=1
SUCCESSFULLY=0

fixture="$root/fixtures"
snapshot="$fixture/snapshots/vault/partitions"

title "'vault partition add as non-owner"
(sandboxed
  (with "a single user"
    import_user "$fixture/tester.sec.asc"

    (with "an unnamed vault with an explicit secrets directory owned by 'tester'"
      "$exe" init --trust-model=web-of-trust --no-auto-import -k etc/keys --first-partition -r etc/recipients --secrets-dir secrets >/dev/null

      (with "another user with access to the vault, which is no recipient"
        as_user "$fixture/b.sec.asc"
        (when "adding a new named partition"
          it "succeeds" && {
            WITH_SNAPSHOT="$snapshot/partition-add-as-another-user-no-recipient" \
            expect_run $SUCCESSFULLY "$exe" partition add --name mine private-partition
          }

          it "creates the expected folder structure" && {
            expect_snapshot "$snapshot/partition-add-as-another-user-no-recipient-directory" .
          }
        )

        (when "adding a resource"
          (with "a resource path without a known partition"
            it "fails" && {
              echo "hi to something" |
              WITH_SNAPSHOT="$snapshot/partition-add-unqualified-resource" \
              expect_run $WITH_FAILURE "$exe" add :hello
            }
          )

          (with "a resource path identifying the partition"
            it "succeeds" && {
              echo "hi to partition" |
              WITH_SNAPSHOT="$snapshot/partition-add-qualified-resource" \
              expect_run $SUCCESSFULLY "$exe" add :private-partition/hello
            }

            it "creates the gpg file at the right spot" && {
              expect_exists private-partition/hello.gpg
            }

            (when "listing resources"
              it "succeeds and shows all resources in all partitions" && {
                WITH_SNAPSHOT="$snapshot/partition-resource-list" \
                expect_run $SUCCESSFULLY "$exe" list
              }
            )

            (when "listing recipients"
              it "fails as it cannot find the prime recipients in the current users keychain" && {
                WITH_SNAPSHOT="$snapshot/partition-recipients-list-fail-missing-key" \
                expect_run $WITH_FAILURE "$exe" recipients list
              }
            )

            (when "showing a resource using an unqualified path"
              it "fails as it cannot find the partition" && {
                WITH_SNAPSHOT="$snapshot/partition-resource-show-unqualified-resource" \
                expect_run $WITH_FAILURE "$exe" show hello
              }
            )

            (when "showing a resource using a qualified path (by path)"
              it "succeeds" && {
                WITH_SNAPSHOT="$snapshot/partition-resource-show-qualified-path" \
                expect_run $SUCCESSFULLY "$exe" show private-partition/hello
              }
            )

            (when "showing a non-existing resource using an qualified path"
              it "fails with an explanatory message" && {
                WITH_SNAPSHOT="$snapshot/partition-resource-show-qualified-non-existing-resource" \
                expect_run $WITH_FAILURE "$exe" show private-partition/non-existing
              }
            )

            (when "removing the resource with unqualified path"
              it "fails as it cannot find the partition" && {
                WITH_SNAPSHOT="$snapshot/partition-remove-unqualified-resource" \
                expect_run $WITH_FAILURE "$exe" remove hello
              }
            )

            (when "removing the resource with qualified path"
              it "succeeds" && {
                WITH_SNAPSHOT="$snapshot/partition-remove-qualified-resource" \
                expect_run $SUCCESSFULLY "$exe" remove private-partition/hello
              }
            )
          )
        )
      )

      (when "listing recipients (as primary user)"
        it "fails as it cannot find the sub-partitions recipients key in the keychain" && {
          WITH_SNAPSHOT="$snapshot/partition-recipients-list-fail-missing-key-as-prime-recipient" \
          expect_run $WITH_FAILURE "$exe" recipients list
        }
      )
    )
  )
)

title "'vault partition add & remove'"
(sandboxed
  (with "a single user"
    import_user "$fixture/tester.sec.asc"

    (with "an unnamed vault with an explicit secrets directory"
      in-space one/vault
      "$exe" init --trust-model=web-of-trust --no-auto-import -k etc/keys -r etc/recipients --secrets-dir secrets >/dev/null

      (when "adding an unnnamed partition"
        it "succeeds" && {
          WITH_SNAPSHOT="$snapshot/partition-first-unnamed" \
          expect_run $SUCCESSFULLY "$exe" partition add first
        }

        it "creates the expected vault file with another vault whose secrets dir is a sibling and a recipients file" && {
          expect_snapshot "$snapshot/partition-first-unnamed-directory" .
        }
      )

      SHARED_NAME=second-partition
      (when "adding another named partition"
        it "succeeds and defaults the name to the path" && {
          WITH_SNAPSHOT="$snapshot/partition-add-second-named" \
          expect_run $SUCCESSFULLY "$exe" partition add --name $SHARED_NAME ./subdir/second
        }

        it "creates the expected vault file" && {
          expect_snapshot "$snapshot/partition-add-second-named-directory" .
        }
      )

      (when "adding another unnamed partition"
        it "succeeds" && {
          WITH_SNAPSHOT="$snapshot/partition-add-third-unnamed-relative-path" \
          expect_run $SUCCESSFULLY "$exe" partition add subdir/third
        }

        it "creates the expected vault file" && {
          expect_snapshot "$snapshot/partition-add-third-named-directory" .
        }
      )

      (when "adding a partition with a name that was already used and an absolute path"
        ABS_PATH=/tmp/some-empty-dir
        mkdir -p $ABS_PATH

        it "succeeds" && {
          WITH_SNAPSHOT="$snapshot/partition-add-fourth-named-absolute-path" \
          expect_run $SUCCESSFULLY "$exe" partitions insert --name $SHARED_NAME "$ABS_PATH"
        }

        it "creates the expected vault file" && {
          expect_snapshot "$snapshot/partition-add-fourth-directory" .
        }
      )

      (when "removing an existing partition by index"
        it "succeeds" && {
          WITH_SNAPSHOT="$snapshot/partition-remove-fourth-by-index" \
          expect_run $SUCCESSFULLY "$exe" partition remove 4
        }

        it "creates the expected vault file" && {
          expect_snapshot "$snapshot/partition-remove-fourth-by-index-directory" .
        }
      )

      (when "removing an existing partition by name"
        it "succeeds" && {
          WITH_SNAPSHOT="$snapshot/partition-remove-third-by-name" \
          expect_run $SUCCESSFULLY "$exe" partition remove third
        }

        it "creates the expected vault file" && {
          expect_snapshot "$snapshot/partition-remove-third-by-name-directory" .
        }
      )

      (when "removing an existing partition by resource directory"
        it "succeeds" && {
          WITH_SNAPSHOT="$snapshot/partition-remove-second-by-resource-dir" \
          expect_run $SUCCESSFULLY "$exe" partition remove ./subdir/second
        }

        it "creates the expected vault file" && {
          expect_snapshot "$snapshot/partition-remove-second-by-resource-dir-directory" .
        }
      )

      (when "adding another partition and selecting both keys explicitly by user id"
        it "succeeds" && {
          WITH_SNAPSHOT="$snapshot/partition-add-multiple-private-keys" \
          expect_run $SUCCESSFULLY "$exe" partition add with-multiple-keys \
                          -i tester@example.com -i b@example.com
        }
      )

      (when "adding another partition and selecting non-existing user-ids"
        it "fails with an appropriate error emssate" && {
          WITH_SNAPSHOT="$snapshot/partition-add-multiple-non-existing-user-ids" \
          expect_run $WITH_FAILURE "$exe" partition add fail -i foo -i bar
        }
      )

      (with "another private key available"
        import_user "$fixture/b.sec.asc"

        (when "adding another partition"
          it "fails thanks to ambiguity" && {
            WITH_SNAPSHOT="$snapshot/partition-add-ambiguous-private-keys" \
            expect_run $WITH_FAILURE "$exe" partition add failing-one
          }
        )
      )
    )
  )
)

title "vault partition failures"
(sandboxed
  (with "a single user"
    import_user "$fixture/tester.sec.asc"
    (with "an unnamed vault and the default secrets directory"
      in-space one/vault
      "$exe" init --secrets-dir . >/dev/null

      (when "adding an unnamed partition"
        it "fails as the partition is contained in the the first partition" && {
          WITH_SNAPSHOT="$snapshot/partition-add-failure" \
          expect_run $WITH_FAILURE "$exe" partition add two
        }
      )

      (when "removing a partition by path that does not exist"
        it "fails" && {
          WITH_SNAPSHOT="$snapshot/partition-remove-by-path-failure-does-not-exist" \
          expect_run $WITH_FAILURE "$exe" partition remove ../some-path-which-is-not-there
        }
      )

      (when "removing a partition by index that does not exist"
        it "fails" && {
          WITH_SNAPSHOT="$snapshot/partition-remove-by-index-failure-does-not-exist" \
          expect_run $WITH_FAILURE "$exe" partitions delete 99
        }
      )

      (when "removing a partition by name that does not exist"
        it "fails" && {
          WITH_SNAPSHOT="$snapshot/partition-remove-by-name-failure-does-not-exist" \
          expect_run $WITH_FAILURE "$exe" partition remove some-invalid-name
        }
      )

      (when "removing a partition by index that does exist but is the leading vault"
        it "fails" && {
          WITH_SNAPSHOT="$snapshot/partition-remove-by-index-failure-cannot-remove-leader" \
          expect_run $WITH_FAILURE "$exe" partition remove 0
        }
      )
    )

    (with "an unnamed vault and the default secrets directory"
      in-space two/vault
      "$exe" init --secrets-dir secrets >/dev/null

      (with "an existing non-empty directory at 'partition'"
        mkdir partition
        touch partition/some-data

        (when "adding a partition to the same directory"
          it "fails" && {
            WITH_SNAPSHOT="$snapshot/partition-add-to-existing-non-empty-directory" \
            expect_run $WITH_FAILURE "$exe" partition add partition
          }
        )
      )

      (with "an existing empty directory at 'partition2'"
        mkdir partition2

        (when "adding a partition to the same directory"
          it "succeeds" && {
            WITH_SNAPSHOT="$snapshot/partition-add-to-existing-empty-directory" \
            expect_run $SUCCESSFULLY "$exe" partition add partition2
          }
        )
      )
    )
  )
)



title "'vault partition add validation"
(sandboxed
  import_user "$fixture/tester.sec.asc"

  (with "a vault with non-unique recipients file configuration across two partition"
    in-space three/vault
    cat <<'YAML' > sy-vault.yml
---
secrets: "one"
gpg_keys: ".gpg-keys"
recipients: ".gpg-id"
---
secrets: "two"
gpg_keys: ".gpg-keys"
recipients: ".gpg-id"
YAML
      it "fails as recipients files must be unique" && {
        WITH_SNAPSHOT="$snapshot/partition-add-failure-duplicate-recipients" \
        expect_run $WITH_FAILURE "$exe" partition add any
      }
  )

  (with "a vault with non-unique names across two partitions"
    in-space four/vault
    cat <<'YAML' > sy-vault.yml
---
secrets: "one"
name: same
gpg_keys: ".gpg-keys"
recipients: "bar"
---
secrets: "two"
name: same
recipients: "foo"
---
secrets: "three"
name: same
recipients: "baz"
YAML
    (when "removing a partition by name"
      it "fails as the name is ambiguous - there are two partitions" && {
        WITH_SNAPSHOT="$snapshot/partition-remove-failure-ambiguous-name" \
        expect_run $WITH_FAILURE "$exe" partition remove same
      }
    )
  )
  (with "a vault with non-unique names across a single partition and the leader"
    in-space five/vault
    cat <<'YAML' > sy-vault.yml
---
secrets: "one"
name: same
gpg_keys: ".gpg-keys"
recipients: "bar"
---
secrets: "two"
name: same
recipients: "foo"
YAML
    (when "removing a partition by name"
      it "succeeds as the leader is not even looked at" && {
        WITH_SNAPSHOT="$snapshot/partition-remove-success-similarly-named-leader" \
        expect_run $SUCCESSFULLY "$exe" partition remove same
      }
      it "creates the expected vault file" && {
        expect_snapshot "$snapshot/partition-remove-success-similarly-named-leader-directory" .
      }
    )
  )
)
