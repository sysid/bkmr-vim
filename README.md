# bkmr.vim

A Vim plugin that provides direct integration with snippet part of [bkmr](https://github.com/sysid/bkmr) without requiring LSP server infrastructure.

## Features

- **Trigger-based completion**: Type `:` followed by letters to get snippet completions
- **Manual completion**: Use `<C-x><C-o>` for omnifunc completion
- **Smart context detection**: Only triggers in appropriate contexts (not URLs, times, etc.)
- **Caching**: Intelligent caching with 5-minute timeout for better performance
- **Snippet interpolation**: Uses bkmr's `--interpolate` flag for processed snippets
- **Search interface**: Interactive snippet search and insertion

## Requirements

- Vim 8.0+ or Neovim
- `bkmr` command-line tool (version 4.24.0+ recommended)
- `jq` (optional, for JSON parsing in older Vim versions)

## Installation

### Using vim-plug

```vim
Plug 'sysid/bkmr-vim'
```

### Using Vundle

```vim
Plugin 'sysid/bkmr-vim'
```

### Manual Installation

```bash
git clone https://github.com/sysid/bkmr.vim ~/.vim/pack/plugins/start/bkmr.vim
```

## Usage

### Basic Completion

1. **Trigger completion**: Type `:` followed by letters, e.g., `:hello`, `:aws`, `:js`
2. **Manual completion**: Press `<C-x><C-o>` in insert mode

### Examples

```
:aws<C-x><C-o>           → Shows AWS-related snippets
:hello<C-x><C-o>         → Shows snippets matching "hello"
:js<C-x><C-o>            → Shows JavaScript snippets
:test<C-x><C-o>          → Shows test-related snippets
```

**Note**: The trigger is simply `:` followed by letters. Complex patterns like `:snip:js` are not supported - use simpler queries like `:js` instead.

### Commands

| Command | Description |
|---------|-------------|
| `:BkmrStatus` | Show plugin status and configuration |
| `:BkmrSearch` | Interactive snippet search and insertion |
| `:BkmrClearCache` | Clear the snippet cache |
| `:BkmrOpen <id>` | Open snippet by ID in external application |

### Default Key Mappings

| Mode | Key | Action |
|------|-----|--------|
| Insert | `:` | Trigger completion (context-aware) |
| Insert | `<C-x><C-o>` | Manual snippet completion |
| Normal | `<leader>bs` | Search snippets |
| Normal | `<leader>bc` | Clear cache |
| Normal | `<leader>bst` | Show status |

## Configuration

### Basic Settings

```vim
" Enable/disable the plugin (default: 1)
let g:bkmr_enabled = 1

" Path to bkmr binary (default: 'bkmr')
let g:bkmr_binary = '/usr/local/bin/bkmr'

" Trigger character for completion (default: ':')
let g:bkmr_trigger_char = ':'

" Maximum number of completions (default: 50)
let g:bkmr_max_completions = 100

" Enable debug messages (default: 0)
let g:bkmr_debug = 1

" Disable default key mappings (default: not set)
let g:bkmr_no_default_mappings = 1
```

### Custom Key Mappings

If you disable default mappings, you can create your own:

```vim
" Custom trigger
inoremap <expr> ; bkmr#trigger_completion()

" Custom manual completion
inoremap <C-s> <C-x><C-o>

" Custom search
nnoremap <F2> :BkmrSearch<CR>
```

### Advanced Configuration

```vim
" Only enable for specific filetypes
augroup bkmr_custom
  autocmd!
  autocmd FileType javascript,python,bash setlocal omnifunc=bkmr#complete
augroup END

" Custom completion behavior
set completeopt=menuone,noinsert,noselect
```

## How It Works

1. **Context Detection**: When you type the trigger character (`:` by default), the plugin checks if you're in a valid snippet context
2. **Query Extraction**: Extracts the text after the trigger as the search query
3. **bkmr Integration**: Calls `bkmr search --json --interpolate -t _snip_` with the query
4. **Completion Display**: Converts results to Vim's completion format
5. **Caching**: Results are cached for 5 minutes to improve performance

## Troubleshooting

### No Completions Appearing

1. Check bkmr is available: `:BkmrStatus`
2. Verify snippets exist: Run `bkmr search -t _snip_` in terminal
3. Enable debug mode: `let g:bkmr_debug = 1`
4. Check Vim's completion settings: `:set omnifunc?`

### Performance Issues

1. Reduce max completions: `let g:bkmr_max_completions = 20`
2. Clear cache if needed: `:BkmrClearCache`
3. Check bkmr database size and optimization

### Context Detection Issues

The plugin skips completion in these contexts:
- `http:` (URLs)
- `12:30` (times) 
- `C:\` (Windows paths)

If it's too restrictive, modify the `s:extract_snippet_query()` function.

## Development

### Testing

```bash
# Test bkmr integration
vim -c ":BkmrStatus"

# Test completion manually
vim -c ":call bkmr#complete(0, 'test')"
```

## Related Projects

- [bkmr](https://github.com/sysid/bkmr) - The snippet manager this plugin integrates with
- [bkmr-lsp](https://github.com/sysid/bkmr-lsp) - LSP server version
- [vim-bkmr-lsp](https://github.com/sysid/vim-bkmr-lsp) - Minimal LSP client

## License

MIT License - see LICENSE file for details.
