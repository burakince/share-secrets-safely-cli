extern crate clap;

use clap::{App, Arg};
use std::env;
use clap::AppSettings;

fn mk_help(kind: &str, prefix: &str) -> String {
    format!(
        "{}A {} can be selected by the directory used to stored its resources, \
         by its name (which may be ambiguous), or by the index in the \
         vault description file.",
        prefix, kind
    )
}

lazy_static! {
    static ref SHELL: Result<String, env::VarError> = env::var("SHELL");
    static ref EDITOR: Result<String, env::VarError> = env::var("EDITOR");
    static ref PARTITION_HELP: String = mk_help("partition", "");
    static ref VAULT_HELP: String = mk_help("vault",
        "Specify the vault which should be the leader.\
         This is particularly relevant for operations with partitions.\
         It has no effect during 'vault init'.");
}

pub struct CLI<'a, 'b>
where
    'a: 'b,
{
    pub app: App<'a, 'b>,
}

impl<'a, 'b> CLI<'a, 'b>
where
    'a: 'b,
{
    pub fn name() -> &'static str {
        "sy"
    }

    pub fn new() -> Self {
        let gpg_key_id = Arg::with_name("gpg-key-id")
            .multiple(true)
            .required(false)
            .takes_value(true)
            .value_name("userid")
            .help("The key-id of the public key identifying a recipient in your gpg keychain.");
        let init = App::new("init")
            .about(
                "Initialize the vault in the current directory. \
                 \
                 If --gpg-key-id is unset, we will use the \
                 only key that you have a secret key for, assuming it is yours.\
                 If you have multiple keys, the --gpg-key-id must be specified \
                 to make the input unambiguous.",
            )
            .arg(
                Arg::with_name("name")
                    .long("name")
                    .short("n")
                    .required(false)
                    .takes_value(true)
                    .value_name("name")
                    .help(
                        "The name of the vault. It can be used to identify the vault more easily, \
                         and its primary purpose is convenience.",
                    ),
            )
            .arg(
                Arg::with_name("secrets-dir")
                    .long("secrets-dir")
                    .short("s")
                    .default_value(".")
                    .required(false)
                    .takes_value(true)
                    .value_name("path")
                    .help("The directory which stores the vaults secrets."),
            )
            .arg(
                Arg::with_name("recipients-file-path")
                    .long("recipients-file")
                    .default_value(".gpg-id")
                    .short("r")
                    .required(false)
                    .takes_value(true)
                    .value_name("path")
                    .help(
                        "The directory to hold the public keys identified by \
                         --gpg-key-id, with signatures.",
                    ),
            )
            .arg(
                Arg::with_name("gpg-keys-dir")
                    .long("gpg-keys-dir")
                    .default_value(".gpg-keys")
                    .short("k")
                    .required(false)
                    .takes_value(true)
                    .value_name("directory")
                    .help(
                        "The directory to hold the public keys identified by \
                         --gpg-key-id, with signatures.",
                    ),
            )
            .arg(gpg_key_id.clone().long("gpg-key-id").short("i"));

        let list = App::new("list")
            .alias("ls")
            .about("List the vault's content.");
        let resource_path = Arg::with_name("path")
            .required(true)
            .multiple(false)
            .takes_value(true)
            .value_name("path")
            .help(
                "Either a vault-relative path to the file as displayed by 'vault show',\
                 a vault-relative path with the '.gpg' suffix, or an absolute \
                 path with or without the '.gpg' suffix.",
            );
        let edit_resource = App::new("edit")
            .arg(
                Arg::with_name("no-try-encrypt")
                    .long("no-try-encrypt")
                    .required(false)
                    .help(
                        "Unless set, we will assure encryption works prior to launching \
                         the editor. This assures you do not accidentally loose your edits.",
                    ),
            )
            .arg(
                Arg::with_name("no-create")
                    .long("no-create")
                    .required(false)
                    .help(
                        "If set, the resource you are editing must exist. \
                         Otherwise it will be created on the fly, allowing you to \
                         add new resources by editing them.",
                    ),
            )
            .arg(
                Arg::with_name("editor")
                    .long("editor")
                    .short("e")
                    .required(false)
                    .takes_value(true)
                    .default_value(EDITOR.as_ref().map(String::as_str).unwrap_or("vim"))
                    .help(
                        "The path to your editor program. It receives the decrypted content as first \
                         argument and is expected to write the changes back to that file before quitting.",
                    ),
            )
            .arg(resource_path.clone())
            .about(
                "Edit a resource. This will decrypt the resource to \
                 a temporary file, open up the $EDITOR you have specified, and re-encrypt the \
                 changed content before deleting it on disk.",
            );
        let show_resource = App::new("show")
            .about("Decrypt a resource")
            .arg(resource_path.clone());
        let spec = Arg::with_name("spec")
            .required(true)
            .multiple(false)
            .takes_value(true)
            .value_name("spec");
        let add_resource = App::new("add")
            .alias("insert")
            .about("Add a new resource to the vault.")
            .arg(spec.clone().help(
                "A specification identifying a mapping from a source file to be stored \
                 in a location of the vault. It takes the form '<src>:<dst>', where \
                 '<src>' is equivalent to '<src>:<src>'.\
                 <dst> should be vault-relative paths, whereas <src> must point to a readable file \
                 and can be empty to read from standard input, such as in ':<dst>'.\
                 If standard input is a TTY, it will open the editor as defined by the \
                 EDITOR environment variable.",
            ));
        let remove_resource = App::new("remove")
            .alias("delete")
            .about("Delete a resource from the vault.")
            .arg(
                resource_path
                    .multiple(true)
                    .help("The vault-relative path of a resource in the vault"),
            );
        let init_recipient = App::new("init").arg(gpg_key_id.clone()).about(
            "Add your single (or the given) recipient key to the vault by exporting the public \
             key and storing it in the vaults local gpg key database. \
             Afterwards someone able to decrypt the vault contents can re-encrypt the content for \
             you.",
        );
        let add_recipient = App::new("add")
            .alias("insert")
            .arg(
                Arg::with_name("signing-key")
                    .long("signing-key")
                    .takes_value(true)
                    .required(false)
                    .conflicts_with("verified")
                    .help(
                        "The userid or fingerprint of the key to use for signing not-yet-verified keys. \
                         It must only be specified if you have access to multiple secret keys which are \
                         also current recipients.",
                    ),
            )
            .arg(
                Arg::with_name("verified")
                    .long("verified")
                    .required(false)
                    .help(
                    "If specified, you indicate that the user id to be added truly belongs to a person you know \
                     and that you have verified that relationship already. \
                     You have used `gpg --sign-key <recipient>` or have set the owner trust to ultimate so that you \
                     can encrypt for the recipient.",
                ),
            )
            .arg(gpg_key_id.clone().required(true))
            .about(
                "Add a new recipient. This will re-encrypt all the vaults content.\
                 \
                 If the '--verified' flag is unset, you will have to specify the fingerprint directly \
                 (as opposed to allowing the recipients email address or name) to indicate you have \
                 assured yourself that it actually belongs to the person.\
                 Otherwise the respective key as identified by its fingerprint will then be imported \
                 and signed. It is expected that you have assured the keys fingerprint belongs to the \
                 recipient. Keys will always be exported into the vaults key directory (if set), which \
                 includes signatures.\
                 Signatures allow others to use the 'Web of Trust' for convenient encryption.",
            );
        let remove_recipient = App::new("remove")
            .alias("delete")
            .about(
                "Remove the given recipient. This will re-encrypt all the vaults content for the remaining \
                 recipients.\
                 \
                 The gpg keychain will not be altered, thus the trust-relationship with the removed recipient is \
                 left intact.\
                 However, the recipients key file will be removed from the vault.",
            )
            .arg(gpg_key_id.required(true));
        let list_recipient = App::new("list")
            .alias("ls")
            .about("List the vaults recipients as identified by the recipients file.");
        let recipients = App::new("recipients")
            .alias("recipient")
            .about("Interact with recipients of a vault. They can encrypt and decrypt its contents.")
            .subcommand(add_recipient)
            .subcommand(remove_recipient)
            .subcommand(list_recipient)
            .subcommand(init_recipient);
        let add_partition = App::new("add")
            .alias("insert")
            .about("Adds a partition to the vault.")
            .arg(
                Arg::with_name("name")
                    .short("n")
                    .long("name")
                    .required(false)
                    .takes_value(true)
                    .help(
                        "The name of the partitions vault to use. If unset, it will default to the basename name of \
                         the partitions resources directory.",
                    ),
            )
            .arg(Arg::with_name("partition-path").required(true).help(
                "The path at which the partition should store resources.\
                 \
                 It may be a relative path which will be adjusted to be relative to the root \
                 of the resource directory of the master vault.\
                 It may also be an absolute directory, which works but removes portability.",
            ));
        let remove_partition = App::new("remove")
            .alias("delete")
            .about(
                "Removes a partition.\
                 Please note that this will not delete any files on disk, but change the \
                 vault description file accordingly.",
            )
            .arg(
                Arg::with_name("partition-selector")
                    .required(true)
                    .takes_value(true)
                    .help(&PARTITION_HELP),
            );
        let partitions = App::new("partitions")
            .alias("partition")
            .about(
                "A partition is essentially another vault, as such it has its own recipients list, name, \
                 keys directory place to store resources.\
                 \
                 Its major promise is that it is non-overlapping with any other partition.\
                 Its main benefit is that it allows one recipients list per resource directory, \
                 effectively emulating simple access control lists.",
            )
            .subcommand(add_partition)
            .subcommand(remove_partition);

        let vault = App::new("vault")
            .about("a variety of vault interactions")
            .subcommand(init)
            .subcommand(add_resource)
            .subcommand(remove_resource)
            .subcommand(recipients)
            .subcommand(show_resource)
            .subcommand(edit_resource)
            .subcommand(list)
            .subcommand(partitions)
            .arg(
                Arg::with_name("vault-selector")
                    .short("s")
                    .long("select")
                    .required(false)
                    .value_name("selector")
                    .help(&VAULT_HELP)
                    .default_value("0"),
            )
            .arg(
                Arg::with_name("config-file")
                    .long("config-file")
                    .short("c")
                    .required(true)
                    .value_name("path")
                    .help("Path to the vault configuration YAML file.")
                    .default_value("./sy-vault.yml"),
            );
        let completions = App::new("completions")
            .about("generate completions for supported shell")
            .arg({
                let arg = Arg::with_name("shell").required(SHELL.is_err()).help(
                    "The name of the shell, or the path to the shell as exposed by the \
                     $SHELL variable.",
                );
                if let Ok(shell) = SHELL.as_ref() {
                    arg.default_value(shell)
                } else {
                    arg
                }
            });
        let app: App = app_from_crate!()
            .setting(AppSettings::VersionlessSubcommands)
            .name(CLI::name())
            .after_help("Read more on https://byron.github.io/share-secrets-safely")
            .version(include_str!("../VERSION"))
            .subcommand(vault)
            .subcommand(completions);

        Self { app }
    }
}
