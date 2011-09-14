" autoload/pandoc_exe.vim
"
" Defines pandoc_execute and pandoc_exec#PandocExecute, for executors
"
python<<EOF
import vim
import sys
import re, string
from os.path import exists, relpath, basename
from subprocess import Popen, PIPE

def pandoc_execute(command, open_when_done=False):
	command = command.split()
	
	# first, we evaluate the output extension
	if basename(command[0]) in ("markdown2pdf", "panbeamer.py"): # always outputs pdfs
		out_extension = "pdf"
	else:
		try:
			out_extension = command[command.index("-t") + 1]
		except ValueError:
			out_extension = "html"
	out = vim.eval('expand("%:r")') + "." + out_extension
	command.extend(["-o", out])

	# we evaluate global vim variables. This way, we can register commands that 
	# pass the value of our variables (e.g, g:pandoc_bibfile).
	for value in command:
		if value.startswith("g:") or value.startswith("b:"):
			vim_value = vim.eval(value)
			if vim_value in ("", [], None):
				if command[command.index(value) - 1] == "--bibliography":
					command.remove(command[command.index(value) - 1])
					command.remove(value)
				else:
					command[command.index(value)] = vim_value
			else:
				if vim_value.__class__ is list:
					if value == "b:pandoc_bibfiles" \
								and command[command.index(value) -1] == "--bibliography":
						command.remove(command[command.index(value) - 1])
						command.remove(value)
						for bib in vim_value:
							command.append("--bibliography")
							command.append(relpath(bib))
				elif vim_value:
					command[command.index(value)] = vim_value

	command.append(relpath(vim.current.buffer.name))

	# we create a temporary buffer where the command and its output will be shown
	
	# we always splitbelow
	splitbelow = bool(int(vim.eval("&splitbelow")))
	if not splitbelow:
		vim.command("set splitbelow")
	
	vim.command("5new")
	vim.current.buffer[0] = "# Press <Esc> to close this"
	vim.current.buffer.append("▶ " + " ".join(command))
	# pressing <esc> on the buffer will delete it
	vim.command("map <buffer> <esc> :bd<cr>")
	# we will highlight some elements in the buffer
	vim.command("syn match PandocOutputMarks /^>>/")
	vim.command("syn match PandocCommand /^▶.*$/hs=s+1")
	vim.command("syn match PandocInstructions /^#.*$/")
	vim.command("hi! link PandocOutputMarks Operator")
	vim.command("hi! link PandocCommand Statement")
	vim.command("hi! link PandocInstructions Comment")

	# we revert splitbelow to its original value
	if not splitbelow:
		vim.command("set nosplitbelow")
	
	# we run pandoc with our arguments
	output = Popen(command, stdout=PIPE, stderr=PIPE).communicate()[0]
	if output not in (None, ""):
		lines = [">> " + line for line in output.split("\n") if line != '']
		for line in lines:
			vim.current.buffer.append(line)
	
	vim.command("setlocal nomodified")
	vim.command("setlocal nomodifiable")

	# finally, we open the created file
	if exists(out) and open_when_done:
		if sys.platform == "darwin":
			pandoc_open_command = "open" #OSX
		elif sys.platform.startswith("linux"):
			pandoc_open_command = "xdg-open" # freedesktop/linux
		elif sys.platform.startswith("win"):
			pandoc_open_command = 'cmd /x \"start' # Windows
		# On windows, we pass commands as an argument to `start`, 
		# which is a cmd.exe builtin, so we have to quote it
		if sys.platform.startswith("win"):
			pandoc_open_command_tail = '"'
		else:
			pandoc_open_command_tail = ''
		
		Popen([pandoc_open_command, out + pandoc_open_command_tail], stdout=PIPE, stderr=PIPE)
EOF

function! pandoc_exec#PandocExecute(command, open_when_done)
python<<EOF
pandoc_execute(vim.eval("a:command"), bool(int(vim.eval("a:open_when_done"))))
EOF
endfunction