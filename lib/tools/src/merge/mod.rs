use failure::{Error, ResultExt};
use json;
use yaml;
use serde::Serialize;

mod types;
pub use self::types::*;
use std::io::{self, stdin};
use std::fs::File;
use treediff::{diff, tools};

mod util;

pub fn reduce(cmds: Vec<Command>, initial_state: Option<State>, mut output: &mut io::Write) -> Result<State, Error> {
    use self::Command::*;
    let mut state = initial_state.unwrap_or_else(State::default);

    for cmd in cmds {
        match cmd {
            SetMergeMode(mode) => {
                state.merge_mode = mode;
            }
            MergeStdin => {
                let value_to_merge = util::de_json_or_yaml_document_support(stdin(), &state)?;
                state = merge(value_to_merge, state)?;
            }
            MergePath(path) => {
                let reader =
                    File::open(&path).context(format!("Failed to open file at '{}' for reading", path.display()))?;
                let value_to_merge = util::de_json_or_yaml_document_support(reader, &state)?;
                state = merge(value_to_merge, state)?;
            }
            SetOutputMode(mode) => {
                state.output_mode = mode;
            }
            Serialize => show(&state.output_mode, &state.value, &mut output)?,
        }
    }
    Ok(state)
}

fn show<V, W>(output_mode: &OutputMode, value: &V, ostream: W) -> Result<(), Error>
where
    V: Serialize,
    W: io::Write,
{
    match *output_mode {
        OutputMode::Json => json::to_writer_pretty(ostream, value).map_err(Into::into),
        OutputMode::Yaml => yaml::to_writer(ostream, value).map_err(Into::into),
    }
}

fn merge(src: json::Value, mut state: State) -> Result<State, Error> {
    match state.value {
        None => {
            state.value = Some(src);
            Ok(state)
        }
        Some(existing_value) => {
            let mut m = tools::Merger::with_filter(existing_value.clone(), NeverDrop::with_mode(&state.merge_mode));
            diff(&existing_value, &src, &mut m);

            if m.filter().clashed_keys.len() > 0 {
                Err(format_err!("{}", m.filter())
                    .context("The merge failed due to conflicts")
                    .into())
            } else {
                state.value = Some(m.into_inner());
                Ok(state)
            }
        }
    }
}
