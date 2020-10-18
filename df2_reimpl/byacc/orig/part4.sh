#! /bin/sh
# This is a shell archive.  Remove anything before this line, then unpack
# it by saving it into a file and typing "sh file".  To overwrite existing
# files, type "sh file -c".  You can also feed this as standard input via
# unshar, or by typing "sh <file", e.g..  If this archive is complete, you
# will see the following message at the end:
#		"End of archive 4 (of 5)."
# Contents:  reader.c test/ftp.y
# Wrapped by rsalz@litchi.bbn.com on Mon Apr  2 11:43:44 1990
PATH=/bin:/usr/bin:/usr/ucb ; export PATH
if test -f 'reader.c' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'reader.c'\"
else
echo shar: Extracting \"'reader.c'\" \(30471 characters\)
sed "s/^X//" >'reader.c' <<'END_OF_FILE'
X#include "defs.h"
X
X/*  The line size must be a positive integer.  One hundred was chosen	*/
X/*  because few lines in Yacc input grammars exceed 100 characters.	*/
X/*  Note that if a line exceeds LINESIZE characters, the line buffer	*/
X/*  will be expanded to accomodate it.					*/
X
X#define LINESIZE 100
X
Xchar *cache;
Xint cinc, cache_size;
X
Xint ntags, tagmax;
Xchar **tag_table;
X
Xchar saw_eof, unionized;
Xchar *cptr, *line;
Xint linesize;
X
Xbucket *goal;
Xint prec;
Xint gensym;
Xchar last_was_action;
X
Xint maxitems;
Xbucket **pitem;
X
Xint maxrules;
Xbucket **plhs;
X
Xint name_pool_size;
Xchar *name_pool;
X
Xchar line_format[] = "#line %d \"%s\"\n";
X
X
Xcachec(c)
Xint c;
X{
X    assert(cinc >= 0);
X    if (cinc >= cache_size)
X    {
X	cache_size += 256;
X	cache = REALLOC(cache, cache_size);
X	if (cache == 0) no_space();
X    }
X    cache[cinc] = c;
X    ++cinc;
X}
X
X
Xget_line()
X{
X    register FILE *f = input_file;
X    register int c;
X    register int i;
X
X    if (saw_eof || (c = getc(f)) == EOF)
X    {
X	if (line) { FREE(line); line = 0; }
X	cptr = 0;
X	saw_eof = 1;
X	return;
X    }
X
X    if (line == 0 || linesize != (LINESIZE + 1))
X    {
X	if (line) FREE(line);
X	linesize = LINESIZE + 1;
X	line = MALLOC(linesize);
X	if (line == 0) no_space();
X    }
X
X    i = 0;
X    ++lineno;
X    for (;;)
X    {
X	line[i]  =  c;
X	if (c == '\n') { cptr = line; return; }
X	if (++i >= linesize)
X	{
X	    linesize += LINESIZE;
X	    line = REALLOC(line, linesize);
X	    if (line ==  0) no_space();
X	}
X	c = getc(f);
X	if (c ==  EOF)
X	{
X	    line[i] = '\n';
X	    saw_eof = 1;
X	    cptr = line;
X	    return;
X	}
X    }
X}
X
X
Xchar *
Xdup_line()
X{
X    register char *p, *s, *t;
X
X    if (line == 0) return (0);
X    s = line;
X    while (*s != '\n') ++s;
X    p = MALLOC(s - line + 1);
X    if (p == 0) no_space();
X
X    s = line;
X    t = p;
X    while ((*t++ = *s++) != '\n') continue;
X    return (p);
X}
X
X
Xskip_comment()
X{
X    register char *s;
X
X    int st_lineno = lineno;
X    char *st_line = dup_line();
X    char *st_cptr = st_line + (cptr - line);
X
X    s = cptr + 2;
X    for (;;)
X    {
X	if (*s == '*' && s[1] == '/')
X	{
X	    cptr = s + 2;
X	    FREE(st_line);
X	    return;
X	}
X	if (*s == '\n')
X	{
X	    get_line();
X	    if (line == 0)
X		unterminated_comment(st_lineno, st_line, st_cptr);
X	    s = cptr;
X	}
X	else
X	    ++s;
X    }
X}
X
X
Xint
Xnextc()
X{
X    register char *s;
X
X    if (line == 0)
X    {
X	get_line();
X	if (line == 0)
X	    return (EOF);
X    }
X
X    s = cptr;
X    for (;;)
X    {
X	switch (*s)
X	{
X	case '\n':
X	    get_line();
X	    if (line == 0) return (EOF);
X	    s = cptr;
X	    break;
X
X	case ' ':
X	case '\t':
X	case '\f':
X	case '\r':
X	case '\v':
X	case ',':
X	case ';':
X	    ++s;
X	    break;
X
X	case '\\':
X	    cptr = s;
X	    return ('%');
X
X	case '/':
X	    if (s[1] == '*')
X	    {
X		cptr = s;
X		skip_comment();
X		s = cptr;
X		break;
X	    }
X	    else if (s[1] == '/')
X	    {
X		get_line();
X		if (line == 0) return (EOF);
X		s = cptr;
X		break;
X	    }
X	    /* fall through */
X
X	default:
X	    cptr = s;
X	    return (*s);
X	}
X    }
X}
X
X
Xint
Xkeyword()
X{
X    register int c;
X    char *t_cptr = cptr;
X
X    c = *++cptr;
X    if (isalpha(c))
X    {
X	cinc = 0;
X	for (;;)
X	{
X	    if (isalpha(c))
X	    {
X		if (isupper(c)) c = tolower(c);
X		cachec(c);
X	    }
X	    else if (isdigit(c) || c == '_' || c == '.' || c == '$')
X		cachec(c);
X	    else
X		break;
X	    c = *++cptr;
X	}
X	cachec(NUL);
X
X	if (strcmp(cache, "token") == 0 || strcmp(cache, "term") == 0)
X	    return (TOKEN);
X	if (strcmp(cache, "type") == 0)
X	    return (TYPE);
X	if (strcmp(cache, "left") == 0)
X	    return (LEFT);
X	if (strcmp(cache, "right") == 0)
X	    return (RIGHT);
X	if (strcmp(cache, "nonassoc") == 0 || strcmp(cache, "binary") == 0)
X	    return (NONASSOC);
X	if (strcmp(cache, "start") == 0)
X	    return (START);
X	if (strcmp(cache, "union") == 0)
X	    return (UNION);
X	if (strcmp(cache, "ident") == 0)
X	    return (IDENT);
X    }
X    else
X    {
X	++cptr;
X	if (c == '{')
X	    return (TEXT);
X	if (c == '%' || c == '\\')
X	    return (MARK);
X	if (c == '<')
X	    return (LEFT);
X	if (c == '>')
X	    return (RIGHT);
X	if (c == '0')
X	    return (TOKEN);
X	if (c == '2')
X	    return (NONASSOC);
X    }
X    syntax_error(lineno, line, t_cptr);
X    /*NOTREACHED*/
X}
X
X
Xcopy_ident()
X{
X    register int c;
X    register FILE *f = output_file;
X
X    c = nextc();
X    if (c == EOF) unexpected_EOF();
X    if (c != '"') syntax_error(lineno, line, cptr);
X    ++outline;
X    fprintf(f, "#ident \"");
X    for (;;)
X    {
X	c = *++cptr;
X	if (c == '\n')
X	{
X	    fprintf(f, "\"\n");
X	    return;
X	}
X	putc(c, f);
X	if (c == '"')
X	{
X	    putc('\n', f);
X	    ++cptr;
X	    return;
X	}
X    }
X}
X
X
Xcopy_text()
X{
X    register int c;
X    int quote;
X    register FILE *f = text_file;
X    int need_newline = 0;
X    int t_lineno = lineno;
X    char *t_line = dup_line();
X    char *t_cptr = t_line + (cptr - line - 2);
X
X    if (*cptr == '\n')
X    {
X	get_line();
X	if (line == 0)
X	    unterminated_text(t_lineno, t_line, t_cptr);
X    }
X    if (!lflag) fprintf(f, line_format, lineno, input_file_name);
X
Xloop:
X    c = *cptr++;
X    switch (c)
X    {
X    case '\n':
X    next_line:
X	putc('\n', f);
X	need_newline = 0;
X	get_line();
X	if (line) goto loop;
X	unterminated_text(t_lineno, t_line, t_cptr);
X
X    case '\'':
X    case '"':
X	{
X	    int s_lineno = lineno;
X	    char *s_line = dup_line();
X	    char *s_cptr = s_line + (cptr - line - 1);
X
X	    quote = c;
X	    putc(c, f);
X	    for (;;)
X	    {
X		c = *cptr++;
X		putc(c, f);
X		if (c == quote)
X		{
X		    need_newline = 1;
X		    FREE(s_line);
X		    goto loop;
X		}
X		if (c == '\n')
X		    unterminated_string(s_lineno, s_line, s_cptr);
X		if (c == '\\')
X		{
X		    c = *cptr++;
X		    putc(c, f);
X		    if (c == '\n')
X		    {
X			get_line();
X			if (line == 0)
X			    unterminated_string(s_lineno, s_line, s_cptr);
X		    }
X		}
X	    }
X	}
X
X    case '/':
X	putc(c, f);
X	need_newline = 1;
X	c = *cptr;
X	if (c == '/')
X	{
X	    putc('*', f);
X	    while ((c = *++cptr) != '\n')
X	    {
X		if (c == '*' && cptr[1] == '/')
X		    fprintf(f, "* ");
X		else
X		    putc(c, f);
X	    }
X	    fprintf(f, "*/");
X	    goto next_line;
X	}
X	if (c == '*')
X	{
X	    int c_lineno = lineno;
X	    char *c_line = dup_line();
X	    char *c_cptr = c_line + (cptr - line - 1);
X
X	    putc('*', f);
X	    ++cptr;
X	    for (;;)
X	    {
X		c = *cptr++;
X		putc(c, f);
X		if (c == '*' && *cptr == '/')
X		{
X		    putc('/', f);
X		    ++cptr;
X		    FREE(c_line);
X		    goto loop;
X		}
X		if (c == '\n')
X		{
X		    get_line();
X		    if (line == 0)
X			unterminated_comment(c_lineno, c_line, c_cptr);
X		}
X	    }
X	}
X	putc('/', f);
X	need_newline = 1;
X	goto loop;
X
X    case '%':
X    case '\\':
X	if (*cptr == '}')
X	{
X	    if (need_newline) putc('\n', f);
X	    ++cptr;
X	    FREE(t_line);
X	    return;
X	}
X	/* fall through */
X
X    default:
X	putc(c, f);
X	need_newline = 1;
X	goto loop;
X    }
X}
X
X
Xcopy_union()
X{
X    register int c;
X    int quote;
X    int depth;
X    int u_lineno = lineno;
X    char *u_line = dup_line();
X    char *u_cptr = u_line + (cptr - line - 6);
X
X    if (unionized) over_unionized(cptr - 6);
X    unionized = 1;
X
X    if (!lflag)
X	fprintf(text_file, line_format, lineno, input_file_name);
X
X    fprintf(text_file, "typedef union");
X    if (dflag) fprintf(union_file, "typedef union");
X
X    depth = 0;
Xloop:
X    c = *cptr++;
X    putc(c, text_file);
X    if (dflag) putc(c, union_file);
X    switch (c)
X    {
X    case '\n':
X    next_line:
X	get_line();
X	if (line == 0) unterminated_union(u_lineno, u_line, u_cptr);
X	goto loop;
X
X    case '{':
X	++depth;
X	goto loop;
X
X    case '}':
X	if (--depth == 0)
X	{
X	    fprintf(text_file, " YYSTYPE;\n");
X	    FREE(u_line);
X	    return;
X	}
X	goto loop;
X
X    case '\'':
X    case '"':
X	{
X	    int s_lineno = lineno;
X	    char *s_line = dup_line();
X	    char *s_cptr = s_line + (cptr - line - 1);
X
X	    quote = c;
X	    for (;;)
X	    {
X		c = *cptr++;
X		putc(c, text_file);
X		if (dflag) putc(c, union_file);
X		if (c == quote)
X		{
X		    FREE(s_line);
X		    goto loop;
X		}
X		if (c == '\n')
X		    unterminated_string(s_lineno, s_line, s_cptr);
X		if (c == '\\')
X		{
X		    c = *cptr++;
X		    putc(c, text_file);
X		    if (dflag) putc(c, union_file);
X		    if (c == '\n')
X		    {
X			get_line();
X			if (line == 0)
X			    unterminated_string(s_lineno, s_line, s_cptr);
X		    }
X		}
X	    }
X	}
X
X    case '/':
X	c = *cptr;
X	if (c == '/')
X	{
X	    putc('*', text_file);
X	    if (dflag) putc('*', union_file);
X	    while ((c = *++cptr) != '\n')
X	    {
X		if (c == '*' && cptr[1] == '/')
X		{
X		    fprintf(text_file, "* ");
X		    if (dflag) fprintf(union_file, "* ");
X		}
X		else
X		{
X		    putc(c, text_file);
X		    if (dflag) putc(c, union_file);
X		}
X	    }
X	    fprintf(text_file, "*/\n");
X	    if (dflag) fprintf(union_file, "*/\n");
X	    goto next_line;
X	}
X	if (c == '*')
X	{
X	    int c_lineno = lineno;
X	    char *c_line = dup_line();
X	    char *c_cptr = c_line + (cptr - line - 1);
X
X	    putc('*', text_file);
X	    if (dflag) putc('*', union_file);
X	    ++cptr;
X	    for (;;)
X	    {
X		c = *cptr++;
X		putc(c, text_file);
X		if (dflag) putc(c, union_file);
X		if (c == '*' && *cptr == '/')
X		{
X		    putc('/', text_file);
X		    if (dflag) putc('/', union_file);
X		    ++cptr;
X		    FREE(c_line);
X		    goto loop;
X		}
X		if (c == '\n')
X		{
X		    get_line();
X		    if (line == 0)
X			unterminated_comment(c_lineno, c_line, c_cptr);
X		}
X	    }
X	}
X	goto loop;
X
X    default:
X	goto loop;
X    }
X}
X
X
Xint
Xhexval(c)
Xint c;
X{
X    if (c >= '0' && c <= '9')
X	return (c - '0');
X    if (c >= 'A' && c <= 'F')
X	return (c - 'A' + 10);
X    if (c >= 'a' && c <= 'f')
X	return (c - 'a' + 10);
X    return (-1);
X}
X
X
Xbucket *
Xget_literal()
X{
X    register int c, quote;
X    register int i;
X    register int n;
X    register char *s;
X    register bucket *bp;
X    int s_lineno = lineno;
X    char *s_line = dup_line();
X    char *s_cptr = s_line + (cptr - line);
X
X    quote = *cptr++;
X    cinc = 0;
X    for (;;)
X    {
X	c = *cptr++;
X	if (c == quote) break;
X	if (c == '\n') unterminated_string(s_lineno, s_line, s_cptr);
X	if (c == '\\')
X	{
X	    char *c_cptr = cptr - 1;
X
X	    c = *cptr++;
X	    switch (c)
X	    {
X	    case '\n':
X		get_line();
X		if (line == 0) unterminated_string(s_lineno, s_line, s_cptr);
X		continue;
X
X	    case '0': case '1': case '2': case '3':
X	    case '4': case '5': case '6': case '7':
X		n = c - '0';
X		c = *cptr;
X		if (IS_OCTAL(c))
X		{
X		    n = (n << 3) + (c - '0');
X		    c = *++cptr;
X		    if (IS_OCTAL(c))
X		    {
X			n = (n << 3) + (c - '0');
X			++cptr;
X		    }
X		}
X		if (n > MAXCHAR) illegal_character(c_cptr);
X		c = n;
X	    	break;
X
X	    case 'x':
X		c = *cptr++;
X		n = hexval(c);
X		if (n < 0 || n >= 16)
X		    illegal_character(c_cptr);
X		for (;;)
X		{
X		    c = *cptr;
X		    i = hexval(c);
X		    if (i < 0 || i >= 16) break;
X		    ++cptr;
X		    n = (n << 4) + i;
X		    if (n > MAXCHAR) illegal_character(c_cptr);
X		}
X		c = n;
X		break;
X
X	    case 'a': c = 7; break;
X	    case 'b': c = '\b'; break;
X	    case 'f': c = '\f'; break;
X	    case 'n': c = '\n'; break;
X	    case 'r': c = '\r'; break;
X	    case 't': c = '\t'; break;
X	    case 'v': c = '\v'; break;
X	    }
X	}
X	cachec(c);
X    }
X    FREE(s_line);
X
X    n = cinc;
X    s = MALLOC(n);
X    if (s == 0) no_space();
X    
X    for (i = 0; i < n; ++i)
X	s[i] = cache[i];
X
X    cinc = 0;
X    if (n == 1)
X	cachec('\'');
X    else
X	cachec('"');
X
X    for (i = 0; i < n; ++i)
X    {
X	c = ((unsigned char *)s)[i];
X	if (c == '\\' || c == cache[0])
X	{
X	    cachec('\\');
X	    cachec(c);
X	}
X	else if (isprint(c))
X	    cachec(c);
X	else
X	{
X	    cachec('\\');
X	    switch (c)
X	    {
X	    case 7: cachec('a'); break;
X	    case '\b': cachec('b'); break;
X	    case '\f': cachec('f'); break;
X	    case '\n': cachec('n'); break;
X	    case '\r': cachec('r'); break;
X	    case '\t': cachec('t'); break;
X	    case '\v': cachec('v'); break;
X	    default:
X		cachec(((c >> 6) & 7) + '0');
X		cachec(((c >> 3) & 7) + '0');
X		cachec((c & 7) + '0');
X		break;
X	    }
X	}
X    }
X
X    if (n == 1)
X	cachec('\'');
X    else
X	cachec('"');
X
X    cachec(NUL);
X    bp = lookup(cache);
X    bp->class = TERM;
X    if (n == 1 && bp->value == UNDEFINED)
X	bp->value = *(unsigned char *)s;
X    FREE(s);
X
X    return (bp);
X}
X
X
Xint
Xis_reserved(name)
Xchar *name;
X{
X    char *s;
X
X    if (strcmp(name, ".") == 0 ||
X	    strcmp(name, "$accept") == 0 ||
X	    strcmp(name, "$end") == 0)
X	return (1);
X
X    if (name[0] == '$' && name[1] == '$' && isdigit(name[2]))
X    {
X	s = name + 3;
X	while (isdigit(*s)) ++s;
X	if (*s == NUL) return (1);
X    }
X
X    return (0);
X}
X
X
Xbucket *
Xget_name()
X{
X    register int c;
X
X    cinc = 0;
X    for (c = *cptr; IS_IDENT(c); c = *++cptr)
X	cachec(c);
X    cachec(NUL);
X
X    if (is_reserved(cache)) used_reserved(cache);
X
X    return (lookup(cache));
X}
X
X
Xint
Xget_number()
X{
X    register int c;
X    register int n;
X
X    n = 0;
X    for (c = *cptr; isdigit(c); c = *++cptr)
X	n = 10*n + (c - '0');
X
X    return (n);
X}
X
X
Xchar *
Xget_tag()
X{
X    register int c;
X    register int i;
X    register char *s;
X    int t_lineno = lineno;
X    char *t_line = dup_line();
X    char *t_cptr = t_line + (cptr - line);
X
X    ++cptr;
X    c = nextc();
X    if (c == EOF) unexpected_EOF();
X    if (!isalpha(c) && c != '_' && c != '$')
X	illegal_tag(t_lineno, t_line, t_cptr);
X
X    cinc = 0;
X    do { cachec(c); c = *++cptr; } while (IS_IDENT(c));
X    cachec(NUL);
X
X    c = nextc();
X    if (c == EOF) unexpected_EOF();
X    if (c != '>')
X	illegal_tag(t_lineno, t_line, t_cptr);
X    ++cptr;
X
X    for (i = 0; i < ntags; ++i)
X    {
X	if (strcmp(cache, tag_table[i]) == 0)
X	    return (tag_table[i]);
X    }
X
X    if (ntags >= tagmax)
X    {
X	tagmax += 16;
X	tag_table = (char **)
X			(tag_table ? REALLOC(tag_table, tagmax*sizeof(char *))
X				   : MALLOC(tagmax*sizeof(char *)));
X	if (tag_table == 0) no_space();
X    }
X
X    s = MALLOC(cinc);
X    if  (s == 0) no_space();
X    strcpy(s, cache);
X    tag_table[ntags] = s;
X    ++ntags;
X    FREE(t_line);
X    return (s);
X}
X
X
Xdeclare_tokens(assoc)
Xint assoc;
X{
X    register int c;
X    register bucket *bp;
X    int value;
X    char *tag = 0;
X
X    if (assoc != TOKEN) ++prec;
X
X    c = nextc();
X    if (c == EOF) unexpected_EOF();
X    if (c == '<')
X    {
X	tag = get_tag();
X	c = nextc();
X	if (c == EOF) unexpected_EOF();
X    }
X
X    for (;;)
X    {
X	if (isalpha(c) || c == '_' || c == '.' || c == '$')
X	    bp = get_name();
X	else if (c == '\'' || c == '"')
X	    bp = get_literal();
X	else
X	    return;
X
X	if (bp == goal) tokenized_start(bp->name);
X	bp->class = TERM;
X
X	if (tag)
X	{
X	    if (bp->tag && tag != bp->tag)
X		retyped_warning(bp->name);
X	    bp->tag = tag;
X	}
X
X	if (assoc != TOKEN)
X	{
X	    if (bp->prec && prec != bp->prec)
X		reprec_warning(bp->name);
X	    bp->assoc = assoc;
X	    bp->prec = prec;
X	}
X
X	c = nextc();
X	if (c == EOF) unexpected_EOF();
X	value = UNDEFINED;
X	if (isdigit(c))
X	{
X	    value = get_number();
X	    if (bp->value != UNDEFINED && value != bp->value)
X		revalued_warning(bp->name);
X	    bp->value = value;
X	    c = nextc();
X	    if (c == EOF) unexpected_EOF();
X	}
X    }
X}
X
X
Xdeclare_types()
X{
X    register int c;
X    register bucket *bp;
X    char *tag;
X
X    c = nextc();
X    if (c == EOF) unexpected_EOF();
X    if (c != '<') syntax_error(lineno, line, cptr);
X    tag = get_tag();
X
X    for (;;)
X    {
X	c = nextc();
X	if (isalpha(c) || c == '_' || c == '.' || c == '$')
X	    bp = get_name();
X	else if (c == '\'' || c == '"')
X	    bp = get_literal();
X	else
X	    return;
X
X	if (bp->tag && tag != bp->tag)
X	    retyped_warning(bp->name);
X	bp->tag = tag;
X    }
X}
X
X
Xdeclare_start()
X{
X    register int c;
X    register bucket *bp;
X
X    c = nextc();
X    if (c == EOF) unexpected_EOF();
X    if (!isalpha(c) && c != '_' && c != '.' && c != '$')
X	syntax_error(lineno, line, cptr);
X    bp = get_name();
X    if (bp->class == TERM)
X	terminal_start(bp->name);
X    if (goal && goal != bp)
X	restarted_warning();
X    goal = bp;
X}
X
X
Xread_declarations()
X{
X    register int c, k;
X
X    cache_size = 256;
X    cache = MALLOC(cache_size);
X    if (cache == 0) no_space();
X
X    for (;;)
X    {
X	c = nextc();
X	if (c == EOF) unexpected_EOF();
X	if (c != '%') syntax_error(lineno, line, cptr);
X	switch (k = keyword())
X	{
X	case MARK:
X	    return;
X
X	case IDENT:
X	    copy_ident();
X	    break;
X
X	case TEXT:
X	    copy_text();
X	    break;
X
X	case UNION:
X	    copy_union();
X	    break;
X
X	case TOKEN:
X	case LEFT:
X	case RIGHT:
X	case NONASSOC:
X	    declare_tokens(k);
X	    break;
X
X	case TYPE:
X	    declare_types();
X	    break;
X
X	case START:
X	    declare_start();
X	    break;
X	}
X    }
X}
X
X
Xinitialize_grammar()
X{
X    nitems = 4;
X    maxitems = 300;
X    pitem = (bucket **) MALLOC(maxitems*sizeof(bucket *));
X    if (pitem == 0) no_space();
X    pitem[0] = 0;
X    pitem[1] = 0;
X    pitem[2] = 0;
X    pitem[3] = 0;
X
X    nrules = 3;
X    maxrules = 100;
X    plhs = (bucket **) MALLOC(maxrules*sizeof(bucket *));
X    if (plhs == 0) no_space();
X    plhs[0] = 0;
X    plhs[1] = 0;
X    plhs[2] = 0;
X    rprec = (short *) MALLOC(maxrules*sizeof(short));
X    if (rprec == 0) no_space();
X    rprec[0] = 0;
X    rprec[1] = 0;
X    rprec[2] = 0;
X    rassoc = (char *) MALLOC(maxrules*sizeof(char));
X    if (rassoc == 0) no_space();
X    rassoc[0] = TOKEN;
X    rassoc[1] = TOKEN;
X    rassoc[2] = TOKEN;
X}
X
X
Xexpand_items()
X{
X    maxitems += 300;
X    pitem = (bucket **) REALLOC(pitem, maxitems*sizeof(bucket *));
X    if (pitem == 0) no_space();
X}
X
X
Xexpand_rules()
X{
X    maxrules += 100;
X    plhs = (bucket **) REALLOC(plhs, maxrules*sizeof(bucket *));
X    if (plhs == 0) no_space();
X    rprec = (short *) REALLOC(rprec, maxrules*sizeof(short));
X    if (rprec == 0) no_space();
X    rassoc = (char *) REALLOC(rassoc, maxrules*sizeof(char));
X    if (rassoc == 0) no_space();
X}
X
X
Xadvance_to_start()
X{
X    register int c;
X    register bucket *bp;
X    char *s_cptr;
X    int s_lineno;
X
X    for (;;)
X    {
X	c = nextc();
X	if (c != '%') break;
X	s_cptr = cptr;
X	switch (keyword())
X	{
X	case MARK:
X	    no_grammar();
X
X	case TEXT:
X	    copy_text();
X	    break;
X
X	case START:
X	    declare_start();
X	    break;
X
X	default:
X	    syntax_error(lineno, line, s_cptr);
X	}
X    }
X
X    c = nextc();
X    if (!isalpha(c) && c != '_' && c != '.' && c != '_')
X	syntax_error(lineno, line, cptr);
X    bp = get_name();
X    if (goal == 0)
X    {
X	if (bp->class == TERM)
X	    terminal_start(bp->name);
X	goal = bp;
X    }
X
X    s_lineno = lineno;
X    c = nextc();
X    if (c == EOF) unexpected_EOF();
X    if (c != ':') syntax_error(lineno, line, cptr);
X    start_rule(bp, s_lineno);
X    ++cptr;
X}
X
X
Xstart_rule(bp, s_lineno)
Xregister bucket *bp;
Xint s_lineno;
X{
X    if (bp->class == TERM)
X	terminal_lhs(s_lineno);
X    bp->class = NONTERM;
X    if (nrules >= maxrules)
X	expand_rules();
X    plhs[nrules] = bp;
X    rprec[nrules] = UNDEFINED;
X    rassoc[nrules] = TOKEN;
X}
X
X
Xend_rule()
X{
X    register int i;
X
X    if (!last_was_action && plhs[nrules]->tag)
X    {
X	for (i = nitems - 1; pitem[i]; --i) continue;
X	if (pitem[i+1]->tag != plhs[nrules]->tag)
X	    default_action_warning();
X    }
X
X    last_was_action = 0;
X    if (nitems >= maxitems) expand_items();
X    pitem[nitems] = 0;
X    ++nitems;
X    ++nrules;
X}
X
X
Xinsert_empty_rule()
X{
X    register bucket *bp, **bpp;
X
X    assert(cache);
X    sprintf(cache, "$$%d", ++gensym);
X    bp = make_bucket(cache);
X    last_symbol->next = bp;
X    last_symbol = bp;
X    bp->tag = plhs[nrules]->tag;
X    bp->class = NONTERM;
X
X    if ((nitems += 2) > maxitems)
X	expand_items();
X    bpp = pitem + nitems - 1;
X    *bpp-- = bp;
X    while (bpp[0] = bpp[-1]) --bpp;
X
X    if (++nrules >= maxrules)
X	expand_rules();
X    plhs[nrules] = plhs[nrules-1];
X    plhs[nrules-1] = bp;
X    rprec[nrules] = rprec[nrules-1];
X    rprec[nrules-1] = 0;
X    rassoc[nrules] = rassoc[nrules-1];
X    rassoc[nrules-1] = TOKEN;
X}
X
X
Xadd_symbol()
X{
X    register int c;
X    register bucket *bp;
X    int s_lineno = lineno;
X
X    c = *cptr;
X    if (c == '\'' || c == '"')
X	bp = get_literal();
X    else
X	bp = get_name();
X
X    c = nextc();
X    if (c == ':')
X    {
X	end_rule();
X	start_rule(bp, s_lineno);
X	++cptr;
X	return;
X    }
X
X    if (last_was_action)
X	insert_empty_rule();
X    last_was_action = 0;
X
X    if (++nitems > maxitems)
X	expand_items();
X    pitem[nitems-1] = bp;
X}
X
X
Xcopy_action()
X{
X    register int c;
X    register int i, n;
X    int depth;
X    int quote;
X    char *tag;
X    register FILE *f = action_file;
X    int a_lineno = lineno;
X    char *a_line = dup_line();
X    char *a_cptr = a_line + (cptr - line);
X
X    if (last_was_action)
X	insert_empty_rule();
X    last_was_action = 1;
X
X    fprintf(f, "case %d:\n", nrules - 2);
X    if (!lflag)
X	fprintf(f, line_format, lineno, input_file_name);
X    if (*cptr == '=') ++cptr;
X
X    n = 0;
X    for (i = nitems - 1; pitem[i]; --i) ++n;
X
X    depth = 0;
Xloop:
X    c = *cptr;
X    if (c == '$')
X    {
X	if (cptr[1] == '<')
X	{
X	    int d_lineno = lineno;
X	    char *d_line = dup_line();
X	    char *d_cptr = d_line + (cptr - line);
X
X	    ++cptr;
X	    tag = get_tag();
X	    c = *cptr;
X	    if (c == '$')
X	    {
X		fprintf(f, "yyval.%s ", tag);
X		++cptr;
X		FREE(d_line);
X		goto loop;
X	    }
X	    else if (isdigit(c))
X	    {
X		i = get_number();
X		if (i > n) dollar_warning(d_lineno, i);
X		fprintf(f, "yyvsp[%d].%s ", i - n, tag);
X		FREE(d_line);
X		goto loop;
X	    }
X	    else if (c == '-' && isdigit(cptr[1]))
X	    {
X		++cptr;
X		i = -get_number() - n;
X		fprintf(f, "yyvsp[%d].%s ", i, tag);
X		FREE(d_line);
X		goto loop;
X	    }
X	    else
X		dollar_error(d_lineno, d_line, d_cptr);
X	}
X	else if (cptr[1] == '$')
X	{
X	    if (ntags)
X	    {
X		tag = plhs[nrules]->tag;
X		if (tag == 0) untyped_lhs();
X		fprintf(f, "yyval.%s ", tag);
X	    }
X	    else
X		fprintf(f, "yyval ");
X	    cptr += 2;
X	    goto loop;
X	}
X	else if (isdigit(cptr[1]))
X	{
X	    ++cptr;
X	    i = get_number();
X	    if (ntags)
X	    {
X		if (i <= 0 || i > n)
X		    unknown_rhs(i);
X		tag = pitem[nitems + i - n - 1]->tag;
X		if (tag == 0) untyped_rhs(i, pitem[nitems + i - n - 1]->name);
X		fprintf(f, "yyvsp[%d].%s ", i - n, tag);
X	    }
X	    else
X	    {
X		if (i > n)
X		    dollar_warning(lineno, i);
X		fprintf(f, "yyvsp[%d]", i - n);
X	    }
X	    goto loop;
X	}
X	else if (cptr[1] == '-')
X	{
X	    cptr += 2;
X	    i = get_number();
X	    if (ntags)
X		unknown_rhs(-i);
X	    fprintf(f, "yyvsp[%d]", -i - n);
X	    goto loop;
X	}
X    }
X    if (isalpha(c) || c == '_' || c == '$')
X    {
X	do
X	{
X	    putc(c, f);
X	    c = *++cptr;
X	} while (isalnum(c) || c == '_' || c == '$');
X	goto loop;
X    }
X    putc(c, f);
X    ++cptr;
X    switch (c)
X    {
X    case '\n':
X    next_line:
X	get_line();
X	if (line) goto loop;
X	unterminated_action(a_lineno, a_line, a_cptr);
X
X    case ';':
X	if (depth > 0) goto loop;
X	fprintf(f, "\nbreak;\n");
X	return;
X
X    case '{':
X	++depth;
X	goto loop;
X
X    case '}':
X	if (--depth > 0) goto loop;
X	fprintf(f, "\nbreak;\n");
X	return;
X
X    case '\'':
X    case '"':
X	{
X	    int s_lineno = lineno;
X	    char *s_line = dup_line();
X	    char *s_cptr = s_line + (cptr - line - 1);
X
X	    quote = c;
X	    for (;;)
X	    {
X		c = *cptr++;
X		putc(c, f);
X		if (c == quote)
X		{
X		    FREE(s_line);
X		    goto loop;
X		}
X		if (c == '\n')
X		    unterminated_string(s_lineno, s_line, s_cptr);
X		if (c == '\\')
X		{
X		    c = *cptr++;
X		    putc(c, f);
X		    if (c == '\n')
X		    {
X			get_line();
X			if (line == 0)
X			    unterminated_string(s_lineno, s_line, s_cptr);
X		    }
X		}
X	    }
X	}
X
X    case '/':
X	c = *cptr;
X	if (c == '/')
X	{
X	    putc('*', f);
X	    while ((c = *++cptr) != '\n')
X	    {
X		if (c == '*' && cptr[1] == '/')
X		    fprintf(f, "* ");
X		else
X		    putc(c, f);
X	    }
X	    fprintf(f, "*/\n");
X	    goto next_line;
X	}
X	if (c == '*')
X	{
X	    int c_lineno = lineno;
X	    char *c_line = dup_line();
X	    char *c_cptr = c_line + (cptr - line - 1);
X
X	    putc('*', f);
X	    ++cptr;
X	    for (;;)
X	    {
X		c = *cptr++;
X		putc(c, f);
X		if (c == '*' && *cptr == '/')
X		{
X		    putc('/', f);
X		    ++cptr;
X		    FREE(c_line);
X		    goto loop;
X		}
X		if (c == '\n')
X		{
X		    get_line();
X		    if (line == 0)
X			unterminated_comment(c_lineno, c_line, c_cptr);
X		}
X	    }
X	}
X	goto loop;
X
X    default:
X	goto loop;
X    }
X}
X
X
Xint
Xmark_symbol()
X{
X    register int c;
X    register bucket *bp;
X
X    c = cptr[1];
X    if (c == '%' || c == '\\')
X    {
X	cptr += 2;
X	return (1);
X    }
X
X    if (c == '=')
X	cptr += 2;
X    else if ((c == 'p' || c == 'P') &&
X	     ((c = cptr[2]) == 'r' || c == 'R') &&
X	     ((c = cptr[3]) == 'e' || c == 'E') &&
X	     ((c = cptr[4]) == 'c' || c == 'C') &&
X	     ((c = cptr[5], !IS_IDENT(c))))
X	cptr += 5;
X    else
X	syntax_error(lineno, line, cptr);
X
X    c = nextc();
X    if (isalpha(c) || c == '_' || c == '.' || c == '$')
X	bp = get_name();
X    else if (c == '\'' || c == '"')
X	bp = get_literal();
X    else
X    {
X	syntax_error(lineno, line, cptr);
X	/*NOTREACHED*/
X    }
X
X    if (rprec[nrules] != UNDEFINED && bp->prec != rprec[nrules])
X	prec_redeclared();
X
X    rprec[nrules] = bp->prec;
X    rassoc[nrules] = bp->assoc;
X    return (0);
X}
X
X
Xread_grammar()
X{
X    register int c;
X
X    initialize_grammar();
X    advance_to_start();
X
X    for (;;)
X    {
X	c = nextc();
X	if (c == EOF) break;
X	if (isalpha(c) || c == '_' || c == '.' || c == '$' || c == '\'' ||
X		c == '"')
X	    add_symbol();
X	else if (c == '{' || c == '=')
X	    copy_action();
X	else if (c == '|')
X	{
X	    end_rule();
X	    start_rule(plhs[nrules-1], 0);
X	    ++cptr;
X	}
X	else if (c == '%')
X	{
X	    if (mark_symbol()) break;
X	}
X	else
X	    syntax_error(lineno, line, cptr);
X    }
X    end_rule();
X}
X
X
Xfree_tags()
X{
X    register int i;
X
X    if (tag_table == 0) return;
X
X    for (i = 0; i < ntags; ++i)
X    {
X	assert(tag_table[i]);
X	FREE(tag_table[i]);
X    }
X    FREE(tag_table);
X}
X
X
Xpack_names()
X{
X    register bucket *bp;
X    register char *p, *s, *t;
X
X    name_pool_size = 13;  /* 13 == sizeof("$end") + sizeof("$accept") */
X    for (bp = first_symbol; bp; bp = bp->next)
X	name_pool_size += strlen(bp->name) + 1;
X    name_pool = MALLOC(name_pool_size);
X    if (name_pool == 0) no_space();
X
X    strcpy(name_pool, "$accept");
X    strcpy(name_pool+8, "$end");
X    t = name_pool + 13;
X    for (bp = first_symbol; bp; bp = bp->next)
X    {
X	p = t;
X	s = bp->name;
X	while (*t++ = *s++) continue;
X	FREE(bp->name);
X	bp->name = p;
X    }
X}
X
X
Xcheck_symbols()
X{
X    register bucket *bp;
X
X    if (goal->class == UNKNOWN)
X	undefined_goal(goal->name);
X
X    for (bp = first_symbol; bp; bp = bp->next)
X    {
X	if (bp->class == UNKNOWN)
X	{
X	    undefined_symbol_warning(bp->name);
X	    bp->class = TERM;
X	}
X    }
X}
X
X
Xpack_symbols()
X{
X    register bucket *bp;
X    register bucket **v;
X    register int i, j, k, n;
X
X    nsyms = 2;
X    ntokens = 1;
X    for (bp = first_symbol; bp; bp = bp->next)
X    {
X	++nsyms;
X	if (bp->class == TERM) ++ntokens;
X    }
X    start_symbol = ntokens;
X    nvars = nsyms - ntokens;
X
X    symbol_name = (char **) MALLOC(nsyms*sizeof(char *));
X    if (symbol_name == 0) no_space();
X    symbol_value = (short *) MALLOC(nsyms*sizeof(short));
X    if (symbol_value == 0) no_space();
X    symbol_prec = (short *) MALLOC(nsyms*sizeof(short));
X    if (symbol_prec == 0) no_space();
X    symbol_assoc = MALLOC(nsyms);
X    if (symbol_assoc == 0) no_space();
X
X    v = (bucket **) MALLOC(nsyms*sizeof(bucket *));
X    if (v == 0) no_space();
X
X    v[0] = 0;
X    v[start_symbol] = 0;
X
X    i = 1;
X    j = start_symbol + 1;
X    for (bp = first_symbol; bp; bp = bp->next)
X    {
X	if (bp->class == TERM)
X	    v[i++] = bp;
X	else
X	    v[j++] = bp;
X    }
X    assert(i == ntokens && j == nsyms);
X
X    for (i = 1; i < ntokens; ++i)
X	v[i]->index = i;
X
X    goal->index = start_symbol + 1;
X    k = start_symbol + 2;
X    while (++i < nsyms)
X	if (v[i] != goal)
X	{
X	    v[i]->index = k;
X	    ++k;
X	}
X
X    goal->value = 0;
X    k = 1;
X    for (i = start_symbol + 1; i < nsyms; ++i)
X    {
X	if (v[i] != goal)
X	{
X	    v[i]->value = k;
X	    ++k;
X	}
X    }
X
X    k = 0;
X    for (i = 1; i < ntokens; ++i)
X    {
X	n = v[i]->value;
X	if (n > 256)
X	{
X	    for (j = k++; j > 0 && symbol_value[j-1] > n; --j)
X		symbol_value[j] = symbol_value[j-1];
X	    symbol_value[j] = n;
X	}
X    }
X
X    if (v[1]->value == UNDEFINED)
X	v[1]->value = 256;
X
X    j = 0;
X    n = 257;
X    for (i = 2; i < ntokens; ++i)
X    {
X	if (v[i]->value == UNDEFINED)
X	{
X	    while (j < k && n == symbol_value[j])
X	    {
X		while (++j < k && n == symbol_value[j]) continue;
X		++n;
X	    }
X	    v[i]->value = n;
X	    ++n;
X	}
X    }
X
X    symbol_name[0] = name_pool + 8;
X    symbol_value[0] = 0;
X    symbol_prec[0] = 0;
X    symbol_assoc[0] = TOKEN;
X    for (i = 1; i < ntokens; ++i)
X    {
X	symbol_name[i] = v[i]->name;
X	symbol_value[i] = v[i]->value;
X	symbol_prec[i] = v[i]->prec;
X	symbol_assoc[i] = v[i]->assoc;
X    }
X    symbol_name[start_symbol] = name_pool;
X    symbol_value[start_symbol] = -1;
X    symbol_prec[start_symbol] = 0;
X    symbol_assoc[start_symbol] = TOKEN;
X    for (++i; i < nsyms; ++i)
X    {
X	k = v[i]->index;
X	symbol_name[k] = v[i]->name;
X	symbol_value[k] = v[i]->value;
X	symbol_prec[k] = v[i]->prec;
X	symbol_assoc[k] = v[i]->assoc;
X    }
X
X    FREE(v);
X}
X
X
Xpack_grammar()
X{
X    register int i, j;
X    int assoc, prec;
X
X    ritem = (short *) MALLOC(nitems*sizeof(short));
X    if (ritem == 0) no_space();
X    rlhs = (short *) MALLOC(nrules*sizeof(short));
X    if (rlhs == 0) no_space();
X    rrhs = (short *) MALLOC((nrules+1)*sizeof(short));
X    if (rrhs == 0) no_space();
X    rprec = (short *) REALLOC(rprec, nrules*sizeof(short));
X    if (rprec == 0) no_space();
X    rassoc = REALLOC(rassoc, nrules);
X    if (rassoc == 0) no_space();
X
X    ritem[0] = -1;
X    ritem[1] = goal->index;
X    ritem[2] = 0;
X    ritem[3] = -2;
X    rlhs[0] = 0;
X    rlhs[1] = 0;
X    rlhs[2] = start_symbol;
X    rrhs[0] = 0;
X    rrhs[1] = 0;
X    rrhs[2] = 1;
X
X    j = 4;
X    for (i = 3; i < nrules; ++i)
X    {
X	rlhs[i] = plhs[i]->index;
X	rrhs[i] = j;
X	assoc = TOKEN;
X	prec = 0;
X	while (pitem[j])
X	{
X	    ritem[j] = pitem[j]->index;
X	    if (pitem[j]->class == TERM)
X	    {
X		prec = pitem[j]->prec;
X		assoc = pitem[j]->assoc;
X	    }
X	    ++j;
X	}
X	ritem[j] = -i;
X	++j;
X	if (rprec[i] == UNDEFINED)
X	{
X	    rprec[i] = prec;
X	    rassoc[i] = assoc;
X	}
X    }
X    rrhs[i] = j;
X
X    FREE(plhs);
X    FREE(pitem);
X}
X
X
Xprint_grammar()
X{
X    register int i, j, k;
X    int spacing;
X    register FILE *f = verbose_file;
X
X    if (!vflag) return;
X
X    k = 1;
X    for (i = 2; i < nrules; ++i)
X    {
X	if (rlhs[i] != rlhs[i-1])
X	{
X	    if (i != 2) fprintf(f, "\n");
X	    fprintf(f, "%4d  %s :", i - 2, symbol_name[rlhs[i]]);
X	    spacing = strlen(symbol_name[rlhs[i]]) + 1;
X	}
X	else
X	{
X	    fprintf(f, "%4d  ", i - 2);
X	    j = spacing;
X	    while (--j >= 0) putc(' ', f);
X	    putc('|', f);
X	}
X
X	while (ritem[k] >= 0)
X	{
X	    fprintf(f, " %s", symbol_name[ritem[k]]);
X	    ++k;
X	}
X	++k;
X	putc('\n', f);
X    }
X}
X
X
Xreader()
X{
X    write_section(banner);
X    create_symbol_table();
X    read_declarations();
X    read_grammar();
X    free_symbol_table();
X    free_tags();
X    pack_names();
X    check_symbols();
X    pack_symbols();
X    pack_grammar();
X    free_symbols();
X    print_grammar();
X}
END_OF_FILE
if [[ 30471 -ne `wc -c <'reader.c'` ]]; then
    echo shar: \"'reader.c'\" unpacked with wrong size!
fi
# end of 'reader.c'
fi
if test -f 'test/ftp.y' -a "${1}" != "-c" ; then 
  echo shar: Will not clobber existing file \"'test/ftp.y'\"
else
echo shar: Extracting \"'test/ftp.y'\" \(22998 characters\)
sed "s/^X//" >'test/ftp.y' <<'END_OF_FILE'
X/*
X * Copyright (c) 1985, 1988 Regents of the University of California.
X * All rights reserved.
X *
X * Redistribution and use in source and binary forms are permitted
X * provided that the above copyright notice and this paragraph are
X * duplicated in all such forms and that any documentation,
X * advertising materials, and other materials related to such
X * distribution and use acknowledge that the software was developed
X * by the University of California, Berkeley.  The name of the
X * University may not be used to endorse or promote products derived
X * from this software without specific prior written permission.
X * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
X * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
X * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
X *
X *	@(#)ftpcmd.y	5.20.1.1 (Berkeley) 3/2/89
X */
X
X/*
X * Grammar for FTP commands.
X * See RFC 959.
X */
X
X%{
X
X#ifndef lint
Xstatic char sccsid[] = "@(#)ftpcmd.y	5.20.1.1 (Berkeley) 3/2/89";
X#endif /* not lint */
X
X#include <sys/param.h>
X#include <sys/socket.h>
X
X#include <netinet/in.h>
X
X#include <arpa/ftp.h>
X
X#include <stdio.h>
X#include <signal.h>
X#include <ctype.h>
X#include <pwd.h>
X#include <setjmp.h>
X#include <syslog.h>
X#include <sys/stat.h>
X#include <time.h>
X
Xextern	struct sockaddr_in data_dest;
Xextern	int logged_in;
Xextern	struct passwd *pw;
Xextern	int guest;
Xextern	int logging;
Xextern	int type;
Xextern	int form;
Xextern	int debug;
Xextern	int timeout;
Xextern	int maxtimeout;
Xextern  int pdata;
Xextern	char hostname[], remotehost[];
Xextern	char proctitle[];
Xextern	char *globerr;
Xextern	int usedefault;
Xextern  int transflag;
Xextern  char tmpline[];
Xchar	**glob();
X
Xstatic	int cmd_type;
Xstatic	int cmd_form;
Xstatic	int cmd_bytesz;
Xchar	cbuf[512];
Xchar	*fromname;
X
Xchar	*index();
X%}
X
X%token
X	A	B	C	E	F	I
X	L	N	P	R	S	T
X
X	SP	CRLF	COMMA	STRING	NUMBER
X
X	USER	PASS	ACCT	REIN	QUIT	PORT
X	PASV	TYPE	STRU	MODE	RETR	STOR
X	APPE	MLFL	MAIL	MSND	MSOM	MSAM
X	MRSQ	MRCP	ALLO	REST	RNFR	RNTO
X	ABOR	DELE	CWD	LIST	NLST	SITE
X	STAT	HELP	NOOP	MKD	RMD	PWD
X	CDUP	STOU	SMNT	SYST	SIZE	MDTM
X
X	UMASK	IDLE	CHMOD
X
X	LEXERR
X
X%start	cmd_list
X
X%%
X
Xcmd_list:	/* empty */
X	|	cmd_list cmd
X		= {
X			fromname = (char *) 0;
X		}
X	|	cmd_list rcmd
X	;
X
Xcmd:		USER SP username CRLF
X		= {
X			user((char *) $3);
X			free((char *) $3);
X		}
X	|	PASS SP password CRLF
X		= {
X			pass((char *) $3);
X			free((char *) $3);
X		}
X	|	PORT SP host_port CRLF
X		= {
X			usedefault = 0;
X			if (pdata >= 0) {
X				(void) close(pdata);
X				pdata = -1;
X			}
X			reply(200, "PORT command successful.");
X		}
X	|	PASV CRLF
X		= {
X			passive();
X		}
X	|	TYPE SP type_code CRLF
X		= {
X			switch (cmd_type) {
X
X			case TYPE_A:
X				if (cmd_form == FORM_N) {
X					reply(200, "Type set to A.");
X					type = cmd_type;
X					form = cmd_form;
X				} else
X					reply(504, "Form must be N.");
X				break;
X
X			case TYPE_E:
X				reply(504, "Type E not implemented.");
X				break;
X
X			case TYPE_I:
X				reply(200, "Type set to I.");
X				type = cmd_type;
X				break;
X
X			case TYPE_L:
X#if NBBY == 8
X				if (cmd_bytesz == 8) {
X					reply(200,
X					    "Type set to L (byte size 8).");
X					type = cmd_type;
X				} else
X					reply(504, "Byte size must be 8.");
X#else /* NBBY == 8 */
X				UNIMPLEMENTED for NBBY != 8
X#endif /* NBBY == 8 */
X			}
X		}
X	|	STRU SP struct_code CRLF
X		= {
X			switch ($3) {
X
X			case STRU_F:
X				reply(200, "STRU F ok.");
X				break;
X
X			default:
X				reply(504, "Unimplemented STRU type.");
X			}
X		}
X	|	MODE SP mode_code CRLF
X		= {
X			switch ($3) {
X
X			case MODE_S:
X				reply(200, "MODE S ok.");
X				break;
X
X			default:
X				reply(502, "Unimplemented MODE type.");
X			}
X		}
X	|	ALLO SP NUMBER CRLF
X		= {
X			reply(202, "ALLO command ignored.");
X		}
X	|	ALLO SP NUMBER SP R SP NUMBER CRLF
X		= {
X			reply(202, "ALLO command ignored.");
X		}
X	|	RETR check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				retrieve((char *) 0, (char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	STOR check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				store((char *) $4, "w", 0);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	APPE check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				store((char *) $4, "a", 0);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	NLST check_login CRLF
X		= {
X			if ($2)
X				send_file_list(".");
X		}
X	|	NLST check_login SP STRING CRLF
X		= {
X			if ($2 && $4 != NULL) 
X				send_file_list((char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	LIST check_login CRLF
X		= {
X			if ($2)
X				retrieve("/bin/ls -lgA", "");
X		}
X	|	LIST check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				retrieve("/bin/ls -lgA %s", (char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	STAT check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				statfilecmd((char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	STAT CRLF
X		= {
X			statcmd();
X		}
X	|	DELE check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				delete((char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	RNTO SP pathname CRLF
X		= {
X			if (fromname) {
X				renamecmd(fromname, (char *) $3);
X				free(fromname);
X				fromname = (char *) 0;
X			} else {
X				reply(503, "Bad sequence of commands.");
X			}
X			free((char *) $3);
X		}
X	|	ABOR CRLF
X		= {
X			reply(225, "ABOR command successful.");
X		}
X	|	CWD check_login CRLF
X		= {
X			if ($2)
X				cwd(pw->pw_dir);
X		}
X	|	CWD check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				cwd((char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	HELP CRLF
X		= {
X			help(cmdtab, (char *) 0);
X		}
X	|	HELP SP STRING CRLF
X		= {
X			register char *cp = (char *)$3;
X
X			if (strncasecmp(cp, "SITE", 4) == 0) {
X				cp = (char *)$3 + 4;
X				if (*cp == ' ')
X					cp++;
X				if (*cp)
X					help(sitetab, cp);
X				else
X					help(sitetab, (char *) 0);
X			} else
X				help(cmdtab, (char *) $3);
X		}
X	|	NOOP CRLF
X		= {
X			reply(200, "NOOP command successful.");
X		}
X	|	MKD check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				makedir((char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	RMD check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				removedir((char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	PWD check_login CRLF
X		= {
X			if ($2)
X				pwd();
X		}
X	|	CDUP check_login CRLF
X		= {
X			if ($2)
X				cwd("..");
X		}
X	|	SITE SP HELP CRLF
X		= {
X			help(sitetab, (char *) 0);
X		}
X	|	SITE SP HELP SP STRING CRLF
X		= {
X			help(sitetab, (char *) $5);
X		}
X	|	SITE SP UMASK check_login CRLF
X		= {
X			int oldmask;
X
X			if ($4) {
X				oldmask = umask(0);
X				(void) umask(oldmask);
X				reply(200, "Current UMASK is %03o", oldmask);
X			}
X		}
X	|	SITE SP UMASK check_login SP octal_number CRLF
X		= {
X			int oldmask;
X
X			if ($4) {
X				if (($6 == -1) || ($6 > 0777)) {
X					reply(501, "Bad UMASK value");
X				} else {
X					oldmask = umask($6);
X					reply(200,
X					    "UMASK set to %03o (was %03o)",
X					    $6, oldmask);
X				}
X			}
X		}
X	|	SITE SP CHMOD check_login SP octal_number SP pathname CRLF
X		= {
X			if ($4 && ($8 != NULL)) {
X				if ($6 > 0777)
X					reply(501,
X				"CHMOD: Mode value must be between 0 and 0777");
X				else if (chmod((char *) $8, $6) < 0)
X					perror_reply(550, (char *) $8);
X				else
X					reply(200, "CHMOD command successful.");
X			}
X			if ($8 != NULL)
X				free((char *) $8);
X		}
X	|	SITE SP IDLE CRLF
X		= {
X			reply(200,
X			    "Current IDLE time limit is %d seconds; max %d",
X				timeout, maxtimeout);
X		}
X	|	SITE SP IDLE SP NUMBER CRLF
X		= {
X			if ($5 < 30 || $5 > maxtimeout) {
X				reply(501,
X			"Maximum IDLE time must be between 30 and %d seconds",
X				    maxtimeout);
X			} else {
X				timeout = $5;
X				(void) alarm((unsigned) timeout);
X				reply(200,
X				    "Maximum IDLE time set to %d seconds",
X				    timeout);
X			}
X		}
X	|	STOU check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				store((char *) $4, "w", 1);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	SYST CRLF
X		= {
X#ifdef unix
X#ifdef BSD
X			reply(215, "UNIX Type: L%d Version: BSD-%d",
X				NBBY, BSD);
X#else /* BSD */
X			reply(215, "UNIX Type: L%d", NBBY);
X#endif /* BSD */
X#else /* unix */
X			reply(215, "UNKNOWN Type: L%d", NBBY);
X#endif /* unix */
X		}
X
X		/*
X		 * SIZE is not in RFC959, but Postel has blessed it and
X		 * it will be in the updated RFC.
X		 *
X		 * Return size of file in a format suitable for
X		 * using with RESTART (we just count bytes).
X		 */
X	|	SIZE check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL)
X				sizecmd((char *) $4);
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X
X		/*
X		 * MDTM is not in RFC959, but Postel has blessed it and
X		 * it will be in the updated RFC.
X		 *
X		 * Return modification time of file as an ISO 3307
X		 * style time. E.g. YYYYMMDDHHMMSS or YYYYMMDDHHMMSS.xxx
X		 * where xxx is the fractional second (of any precision,
X		 * not necessarily 3 digits)
X		 */
X	|	MDTM check_login SP pathname CRLF
X		= {
X			if ($2 && $4 != NULL) {
X				struct stat stbuf;
X				if (stat((char *) $4, &stbuf) < 0)
X					perror_reply(550, "%s", (char *) $4);
X				else if ((stbuf.st_mode&S_IFMT) != S_IFREG) {
X					reply(550, "%s: not a plain file.",
X						(char *) $4);
X				} else {
X					register struct tm *t;
X					struct tm *gmtime();
X					t = gmtime(&stbuf.st_mtime);
X					reply(213,
X					    "19%02d%02d%02d%02d%02d%02d",
X					    t->tm_year, t->tm_mon+1, t->tm_mday,
X					    t->tm_hour, t->tm_min, t->tm_sec);
X				}
X			}
X			if ($4 != NULL)
X				free((char *) $4);
X		}
X	|	QUIT CRLF
X		= {
X			reply(221, "Goodbye.");
X			dologout(0);
X		}
X	|	error CRLF
X		= {
X			yyerrok;
X		}
X	;
Xrcmd:		RNFR check_login SP pathname CRLF
X		= {
X			char *renamefrom();
X
X			if ($2 && $4) {
X				fromname = renamefrom((char *) $4);
X				if (fromname == (char *) 0 && $4) {
X					free((char *) $4);
X				}
X			}
X		}
X	;
X		
Xusername:	STRING
X	;
X
Xpassword:	/* empty */
X		= {
X			*(char **)&($$) = "";
X		}
X	|	STRING
X	;
X
Xbyte_size:	NUMBER
X	;
X
Xhost_port:	NUMBER COMMA NUMBER COMMA NUMBER COMMA NUMBER COMMA 
X		NUMBER COMMA NUMBER
X		= {
X			register char *a, *p;
X
X			a = (char *)&data_dest.sin_addr;
X			a[0] = $1; a[1] = $3; a[2] = $5; a[3] = $7;
X			p = (char *)&data_dest.sin_port;
X			p[0] = $9; p[1] = $11;
X			data_dest.sin_family = AF_INET;
X		}
X	;
X
Xform_code:	N
X	= {
X		$$ = FORM_N;
X	}
X	|	T
X	= {
X		$$ = FORM_T;
X	}
X	|	C
X	= {
X		$$ = FORM_C;
X	}
X	;
X
Xtype_code:	A
X	= {
X		cmd_type = TYPE_A;
X		cmd_form = FORM_N;
X	}
X	|	A SP form_code
X	= {
X		cmd_type = TYPE_A;
X		cmd_form = $3;
X	}
X	|	E
X	= {
X		cmd_type = TYPE_E;
X		cmd_form = FORM_N;
X	}
X	|	E SP form_code
X	= {
X		cmd_type = TYPE_E;
X		cmd_form = $3;
X	}
X	|	I
X	= {
X		cmd_type = TYPE_I;
X	}
X	|	L
X	= {
X		cmd_type = TYPE_L;
X		cmd_bytesz = NBBY;
X	}
X	|	L SP byte_size
X	= {
X		cmd_type = TYPE_L;
X		cmd_bytesz = $3;
X	}
X	/* this is for a bug in the BBN ftp */
X	|	L byte_size
X	= {
X		cmd_type = TYPE_L;
X		cmd_bytesz = $2;
X	}
X	;
X
Xstruct_code:	F
X	= {
X		$$ = STRU_F;
X	}
X	|	R
X	= {
X		$$ = STRU_R;
X	}
X	|	P
X	= {
X		$$ = STRU_P;
X	}
X	;
X
Xmode_code:	S
X	= {
X		$$ = MODE_S;
X	}
X	|	B
X	= {
X		$$ = MODE_B;
X	}
X	|	C
X	= {
X		$$ = MODE_C;
X	}
X	;
X
Xpathname:	pathstring
X	= {
X		/*
X		 * Problem: this production is used for all pathname
X		 * processing, but only gives a 550 error reply.
X		 * This is a valid reply in some cases but not in others.
X		 */
X		if (logged_in && $1 && strncmp((char *) $1, "~", 1) == 0) {
X			*(char **)&($$) = *glob((char *) $1);
X			if (globerr != NULL) {
X				reply(550, globerr);
X				$$ = NULL;
X			}
X			free((char *) $1);
X		} else
X			$$ = $1;
X	}
X	;
X
Xpathstring:	STRING
X	;
X
Xoctal_number:	NUMBER
X	= {
X		register int ret, dec, multby, digit;
X
X		/*
X		 * Convert a number that was read as decimal number
X		 * to what it would be if it had been read as octal.
X		 */
X		dec = $1;
X		multby = 1;
X		ret = 0;
X		while (dec) {
X			digit = dec%10;
X			if (digit > 7) {
X				ret = -1;
X				break;
X			}
X			ret += digit * multby;
X			multby *= 8;
X			dec /= 10;
X		}
X		$$ = ret;
X	}
X	;
X
Xcheck_login:	/* empty */
X	= {
X		if (logged_in)
X			$$ = 1;
X		else {
X			reply(530, "Please login with USER and PASS.");
X			$$ = 0;
X		}
X	}
X	;
X
X%%
X
Xextern jmp_buf errcatch;
X
X#define	CMD	0	/* beginning of command */
X#define	ARGS	1	/* expect miscellaneous arguments */
X#define	STR1	2	/* expect SP followed by STRING */
X#define	STR2	3	/* expect STRING */
X#define	OSTR	4	/* optional SP then STRING */
X#define	ZSTR1	5	/* SP then optional STRING */
X#define	ZSTR2	6	/* optional STRING after SP */
X#define	SITECMD	7	/* SITE command */
X#define	NSTR	8	/* Number followed by a string */
X
Xstruct tab {
X	char	*name;
X	short	token;
X	short	state;
X	short	implemented;	/* 1 if command is implemented */
X	char	*help;
X};
X
Xstruct tab cmdtab[] = {		/* In order defined in RFC 765 */
X	{ "USER", USER, STR1, 1,	"<sp> username" },
X	{ "PASS", PASS, ZSTR1, 1,	"<sp> password" },
X	{ "ACCT", ACCT, STR1, 0,	"(specify account)" },
X	{ "SMNT", SMNT, ARGS, 0,	"(structure mount)" },
X	{ "REIN", REIN, ARGS, 0,	"(reinitialize server state)" },
X	{ "QUIT", QUIT, ARGS, 1,	"(terminate service)", },
X	{ "PORT", PORT, ARGS, 1,	"<sp> b0, b1, b2, b3, b4" },
X	{ "PASV", PASV, ARGS, 1,	"(set server in passive mode)" },
X	{ "TYPE", TYPE, ARGS, 1,	"<sp> [ A | E | I | L ]" },
X	{ "STRU", STRU, ARGS, 1,	"(specify file structure)" },
X	{ "MODE", MODE, ARGS, 1,	"(specify transfer mode)" },
X	{ "RETR", RETR, STR1, 1,	"<sp> file-name" },
X	{ "STOR", STOR, STR1, 1,	"<sp> file-name" },
X	{ "APPE", APPE, STR1, 1,	"<sp> file-name" },
X	{ "MLFL", MLFL, OSTR, 0,	"(mail file)" },
X	{ "MAIL", MAIL, OSTR, 0,	"(mail to user)" },
X	{ "MSND", MSND, OSTR, 0,	"(mail send to terminal)" },
X	{ "MSOM", MSOM, OSTR, 0,	"(mail send to terminal or mailbox)" },
X	{ "MSAM", MSAM, OSTR, 0,	"(mail send to terminal and mailbox)" },
X	{ "MRSQ", MRSQ, OSTR, 0,	"(mail recipient scheme question)" },
X	{ "MRCP", MRCP, STR1, 0,	"(mail recipient)" },
X	{ "ALLO", ALLO, ARGS, 1,	"allocate storage (vacuously)" },
X	{ "REST", REST, ARGS, 0,	"(restart command)" },
X	{ "RNFR", RNFR, STR1, 1,	"<sp> file-name" },
X	{ "RNTO", RNTO, STR1, 1,	"<sp> file-name" },
X	{ "ABOR", ABOR, ARGS, 1,	"(abort operation)" },
X	{ "DELE", DELE, STR1, 1,	"<sp> file-name" },
X	{ "CWD",  CWD,  OSTR, 1,	"[ <sp> directory-name ]" },
X	{ "XCWD", CWD,	OSTR, 1,	"[ <sp> directory-name ]" },
X	{ "LIST", LIST, OSTR, 1,	"[ <sp> path-name ]" },
X	{ "NLST", NLST, OSTR, 1,	"[ <sp> path-name ]" },
X	{ "SITE", SITE, SITECMD, 1,	"site-cmd [ <sp> arguments ]" },
X	{ "SYST", SYST, ARGS, 1,	"(get type of operating system)" },
X	{ "STAT", STAT, OSTR, 1,	"[ <sp> path-name ]" },
X	{ "HELP", HELP, OSTR, 1,	"[ <sp> <string> ]" },
X	{ "NOOP", NOOP, ARGS, 1,	"" },
X	{ "MKD",  MKD,  STR1, 1,	"<sp> path-name" },
X	{ "XMKD", MKD,  STR1, 1,	"<sp> path-name" },
X	{ "RMD",  RMD,  STR1, 1,	"<sp> path-name" },
X	{ "XRMD", RMD,  STR1, 1,	"<sp> path-name" },
X	{ "PWD",  PWD,  ARGS, 1,	"(return current directory)" },
X	{ "XPWD", PWD,  ARGS, 1,	"(return current directory)" },
X	{ "CDUP", CDUP, ARGS, 1,	"(change to parent directory)" },
X	{ "XCUP", CDUP, ARGS, 1,	"(change to parent directory)" },
X	{ "STOU", STOU, STR1, 1,	"<sp> file-name" },
X	{ "SIZE", SIZE, OSTR, 1,	"<sp> path-name" },
X	{ "MDTM", MDTM, OSTR, 1,	"<sp> path-name" },
X	{ NULL,   0,    0,    0,	0 }
X};
X
Xstruct tab sitetab[] = {
X	{ "UMASK", UMASK, ARGS, 1,	"[ <sp> umask ]" },
X	{ "IDLE", IDLE, ARGS, 1,	"[ <sp> maximum-idle-time ]" },
X	{ "CHMOD", CHMOD, NSTR, 1,	"<sp> mode <sp> file-name" },
X	{ "HELP", HELP, OSTR, 1,	"[ <sp> <string> ]" },
X	{ NULL,   0,    0,    0,	0 }
X};
X
Xstruct tab *
Xlookup(p, cmd)
X	register struct tab *p;
X	char *cmd;
X{
X
X	for (; p->name != NULL; p++)
X		if (strcmp(cmd, p->name) == 0)
X			return (p);
X	return (0);
X}
X
X#include <arpa/telnet.h>
X
X/*
X * getline - a hacked up version of fgets to ignore TELNET escape codes.
X */
Xchar *
Xgetline(s, n, iop)
X	char *s;
X	register FILE *iop;
X{
X	register c;
X	register char *cs;
X
X	cs = s;
X/* tmpline may contain saved command from urgent mode interruption */
X	for (c = 0; tmpline[c] != '\0' && --n > 0; ++c) {
X		*cs++ = tmpline[c];
X		if (tmpline[c] == '\n') {
X			*cs++ = '\0';
X			if (debug)
X				syslog(LOG_DEBUG, "command: %s", s);
X			tmpline[0] = '\0';
X			return(s);
X		}
X		if (c == 0)
X			tmpline[0] = '\0';
X	}
X	while ((c = getc(iop)) != EOF) {
X		c &= 0377;
X		if (c == IAC) {
X		    if ((c = getc(iop)) != EOF) {
X			c &= 0377;
X			switch (c) {
X			case WILL:
X			case WONT:
X				c = getc(iop);
X				printf("%c%c%c", IAC, DONT, 0377&c);
X				(void) fflush(stdout);
X				continue;
X			case DO:
X			case DONT:
X				c = getc(iop);
X				printf("%c%c%c", IAC, WONT, 0377&c);
X				(void) fflush(stdout);
X				continue;
X			case IAC:
X				break;
X			default:
X				continue;	/* ignore command */
X			}
X		    }
X		}
X		*cs++ = c;
X		if (--n <= 0 || c == '\n')
X			break;
X	}
X	if (c == EOF && cs == s)
X		return (NULL);
X	*cs++ = '\0';
X	if (debug)
X		syslog(LOG_DEBUG, "command: %s", s);
X	return (s);
X}
X
Xstatic int
Xtoolong()
X{
X	time_t now;
X	extern char *ctime();
X	extern time_t time();
X
X	reply(421,
X	  "Timeout (%d seconds): closing control connection.", timeout);
X	(void) time(&now);
X	if (logging) {
X		syslog(LOG_INFO,
X			"User %s timed out after %d seconds at %s",
X			(pw ? pw -> pw_name : "unknown"), timeout, ctime(&now));
X	}
X	dologout(1);
X}
X
Xyylex()
X{
X	static int cpos, state;
X	register char *cp, *cp2;
X	register struct tab *p;
X	int n;
X	char c, *strpbrk();
X	char *copy();
X
X	for (;;) {
X		switch (state) {
X
X		case CMD:
X			(void) signal(SIGALRM, toolong);
X			(void) alarm((unsigned) timeout);
X			if (getline(cbuf, sizeof(cbuf)-1, stdin) == NULL) {
X				reply(221, "You could at least say goodbye.");
X				dologout(0);
X			}
X			(void) alarm(0);
X#ifdef SETPROCTITLE
X			if (strncasecmp(cbuf, "PASS", 4) != NULL)
X				setproctitle("%s: %s", proctitle, cbuf);
X#endif /* SETPROCTITLE */
X			if ((cp = index(cbuf, '\r'))) {
X				*cp++ = '\n';
X				*cp = '\0';
X			}
X			if ((cp = strpbrk(cbuf, " \n")))
X				cpos = cp - cbuf;
X			if (cpos == 0)
X				cpos = 4;
X			c = cbuf[cpos];
X			cbuf[cpos] = '\0';
X			upper(cbuf);
X			p = lookup(cmdtab, cbuf);
X			cbuf[cpos] = c;
X			if (p != 0) {
X				if (p->implemented == 0) {
X					nack(p->name);
X					longjmp(errcatch,0);
X					/* NOTREACHED */
X				}
X				state = p->state;
X				*(char **)&yylval = p->name;
X				return (p->token);
X			}
X			break;
X
X		case SITECMD:
X			if (cbuf[cpos] == ' ') {
X				cpos++;
X				return (SP);
X			}
X			cp = &cbuf[cpos];
X			if ((cp2 = strpbrk(cp, " \n")))
X				cpos = cp2 - cbuf;
X			c = cbuf[cpos];
X			cbuf[cpos] = '\0';
X			upper(cp);
X			p = lookup(sitetab, cp);
X			cbuf[cpos] = c;
X			if (p != 0) {
X				if (p->implemented == 0) {
X					state = CMD;
X					nack(p->name);
X					longjmp(errcatch,0);
X					/* NOTREACHED */
X				}
X				state = p->state;
X				*(char **)&yylval = p->name;
X				return (p->token);
X			}
X			state = CMD;
X			break;
X
X		case OSTR:
X			if (cbuf[cpos] == '\n') {
X				state = CMD;
X				return (CRLF);
X			}
X			/* FALLTHROUGH */
X
X		case STR1:
X		case ZSTR1:
X		dostr1:
X			if (cbuf[cpos] == ' ') {
X				cpos++;
X				state = state == OSTR ? STR2 : ++state;
X				return (SP);
X			}
X			break;
X
X		case ZSTR2:
X			if (cbuf[cpos] == '\n') {
X				state = CMD;
X				return (CRLF);
X			}
X			/* FALLTHROUGH */
X
X		case STR2:
X			cp = &cbuf[cpos];
X			n = strlen(cp);
X			cpos += n - 1;
X			/*
X			 * Make sure the string is nonempty and \n terminated.
X			 */
X			if (n > 1 && cbuf[cpos] == '\n') {
X				cbuf[cpos] = '\0';
X				*(char **)&yylval = copy(cp);
X				cbuf[cpos] = '\n';
X				state = ARGS;
X				return (STRING);
X			}
X			break;
X
X		case NSTR:
X			if (cbuf[cpos] == ' ') {
X				cpos++;
X				return (SP);
X			}
X			if (isdigit(cbuf[cpos])) {
X				cp = &cbuf[cpos];
X				while (isdigit(cbuf[++cpos]))
X					;
X				c = cbuf[cpos];
X				cbuf[cpos] = '\0';
X				yylval = atoi(cp);
X				cbuf[cpos] = c;
X				state = STR1;
X				return (NUMBER);
X			}
X			state = STR1;
X			goto dostr1;
X
X		case ARGS:
X			if (isdigit(cbuf[cpos])) {
X				cp = &cbuf[cpos];
X				while (isdigit(cbuf[++cpos]))
X					;
X				c = cbuf[cpos];
X				cbuf[cpos] = '\0';
X				yylval = atoi(cp);
X				cbuf[cpos] = c;
X				return (NUMBER);
X			}
X			switch (cbuf[cpos++]) {
X
X			case '\n':
X				state = CMD;
X				return (CRLF);
X
X			case ' ':
X				return (SP);
X
X			case ',':
X				return (COMMA);
X
X			case 'A':
X			case 'a':
X				return (A);
X
X			case 'B':
X			case 'b':
X				return (B);
X
X			case 'C':
X			case 'c':
X				return (C);
X
X			case 'E':
X			case 'e':
X				return (E);
X
X			case 'F':
X			case 'f':
X				return (F);
X
X			case 'I':
X			case 'i':
X				return (I);
X
X			case 'L':
X			case 'l':
X				return (L);
X
X			case 'N':
X			case 'n':
X				return (N);
X
X			case 'P':
X			case 'p':
X				return (P);
X
X			case 'R':
X			case 'r':
X				return (R);
X
X			case 'S':
X			case 's':
X				return (S);
X
X			case 'T':
X			case 't':
X				return (T);
X
X			}
X			break;
X
X		default:
X			fatal("Unknown state in scanner.");
X		}
X		yyerror((char *) 0);
X		state = CMD;
X		longjmp(errcatch,0);
X	}
X}
X
Xupper(s)
X	register char *s;
X{
X	while (*s != '\0') {
X		if (islower(*s))
X			*s = toupper(*s);
X		s++;
X	}
X}
X
Xchar *
Xcopy(s)
X	char *s;
X{
X	char *p;
X	extern char *malloc(), *strcpy();
X
X	p = malloc((unsigned) strlen(s) + 1);
X	if (p == NULL)
X		fatal("Ran out of memory.");
X	(void) strcpy(p, s);
X	return (p);
X}
X
Xhelp(ctab, s)
X	struct tab *ctab;
X	char *s;
X{
X	register struct tab *c;
X	register int width, NCMDS;
X	char *type;
X
X	if (ctab == sitetab)
X		type = "SITE ";
X	else
X		type = "";
X	width = 0, NCMDS = 0;
X	for (c = ctab; c->name != NULL; c++) {
X		int len = strlen(c->name);
X
X		if (len > width)
X			width = len;
X		NCMDS++;
X	}
X	width = (width + 8) &~ 7;
X	if (s == 0) {
X		register int i, j, w;
X		int columns, lines;
X
X		lreply(214, "The following %scommands are recognized %s.",
X		    type, "(* =>'s unimplemented)");
X		columns = 76 / width;
X		if (columns == 0)
X			columns = 1;
X		lines = (NCMDS + columns - 1) / columns;
X		for (i = 0; i < lines; i++) {
X			printf("   ");
X			for (j = 0; j < columns; j++) {
X				c = ctab + j * lines + i;
X				printf("%s%c", c->name,
X					c->implemented ? ' ' : '*');
X				if (c + lines >= &ctab[NCMDS])
X					break;
X				w = strlen(c->name) + 1;
X				while (w < width) {
X					putchar(' ');
X					w++;
X				}
X			}
X			printf("\r\n");
X		}
X		(void) fflush(stdout);
X		reply(214, "Direct comments to ftp-bugs@%s.", hostname);
X		return;
X	}
X	upper(s);
X	c = lookup(ctab, s);
X	if (c == (struct tab *)0) {
X		reply(502, "Unknown command %s.", s);
X		return;
X	}
X	if (c->implemented)
X		reply(214, "Syntax: %s%s %s", type, c->name, c->help);
X	else
X		reply(214, "%s%-*s\t%s; unimplemented.", type, width,
X		    c->name, c->help);
X}
X
Xsizecmd(filename)
Xchar *filename;
X{
X	switch (type) {
X	case TYPE_L:
X	case TYPE_I: {
X		struct stat stbuf;
X		if (stat(filename, &stbuf) < 0 ||
X		    (stbuf.st_mode&S_IFMT) != S_IFREG)
X			reply(550, "%s: not a plain file.", filename);
X		else
X			reply(213, "%lu", stbuf.st_size);
X		break;}
X	case TYPE_A: {
X		FILE *fin;
X		register int c, count;
X		struct stat stbuf;
X		fin = fopen(filename, "r");
X		if (fin == NULL) {
X			perror_reply(550, filename);
X			return;
X		}
X		if (fstat(fileno(fin), &stbuf) < 0 ||
X		    (stbuf.st_mode&S_IFMT) != S_IFREG) {
X			reply(550, "%s: not a plain file.", filename);
X			(void) fclose(fin);
X			return;
X		}
X
X		count = 0;
X		while((c=getc(fin)) != EOF) {
X			if (c == '\n')	/* will get expanded to \r\n */
X				count++;
X			count++;
X		}
X		(void) fclose(fin);
X
X		reply(213, "%ld", count);
X		break;}
X	default:
X		reply(504, "SIZE not implemented for Type %c.", "?AEIL"[type]);
X	}
X}
END_OF_FILE
if [[ 22998 -ne `wc -c <'test/ftp.y'` ]]; then
    echo shar: \"'test/ftp.y'\" unpacked with wrong size!
fi
# end of 'test/ftp.y'
fi
echo shar: End of archive 4 \(of 5\).
cp /dev/null ark4isdone
MISSING=""
for I in 1 2 3 4 5 ; do
    if test ! -f ark${I}isdone ; then
	MISSING="${MISSING} ${I}"
    fi
done
if test "${MISSING}" = "" ; then
    echo You have unpacked all 5 archives.
    rm -f ark[1-9]isdone
else
    echo You still need to unpack the following archives:
    echo "        " ${MISSING}
fi
##  End of shell archive.
exit 0
