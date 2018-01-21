#[macro_use]
extern crate failure;
#[macro_use]
extern crate failure_derive;
extern crate glob;
extern crate gpgme;
extern crate itertools;
extern crate serde;
#[macro_use]
extern crate serde_derive;
extern crate serde_yaml;
extern crate sheesy_types;
extern crate yaml_rust;
extern crate mktemp;


pub mod error;
mod util;
mod base;
mod dispatch;
mod recipients;
mod init;
mod resource;

pub use base::Vault;
pub use dispatch::do_it;
