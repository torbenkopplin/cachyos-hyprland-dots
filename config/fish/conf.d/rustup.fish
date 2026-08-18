# Cargo environment, for either way the toolchain can get here.
#
# ~/.cargo/env.fish is created by *rustup* and by nothing else. The CachyOS
# `rust` package -- which is what install.sh leaves you on, since rustup
# conflicts with it -- puts cargo straight on PATH at /usr/bin/cargo and writes
# no env file at all. Sourcing it unconditionally therefore prints an error on
# every new shell on exactly the setup this repo installs.
if test -f "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
end

# `cargo install` drops binaries here whichever toolchain provided cargo, and
# with the repo package nothing else adds it -- rustup's env.fish is normally
# what does. fish_add_path is idempotent, so this is safe alongside the source
# above.
if test -d "$HOME/.cargo/bin"
    fish_add_path "$HOME/.cargo/bin"
end
