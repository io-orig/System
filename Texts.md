
## [MODULE Texts](https://github.com/io-core/Edit/blob/main/Texts.Mod)

  ## Imports:
` Files Fonts`

## Constants:
```
 (*scanner symbol classes*)
    Inval* = 0;         (*invalid symbol*)
    Name* = 1;          (*name s (length len)*)
    String* = 2;        (*literal string s (length len)*)
    Int* = 3;           (*integer i (decimal or hexadecimal)*)
    Real* = 4;          (*real number x*)
    Char* = 6;          (*special character c*)

    (* TextBlock = TextTag offset run {run} "0" len {AsciiCode}.
      run = fnt [name] col voff len. *)

    TAB = 9X; CR = 0DX;
    TextTag = 0F1X;
    replace* = 0; insert* = 1; delete* = 2; unmark* = 3;  (*op-codes*)

```
## Types:
```
 Piece = POINTER TO PieceDesc;
    PieceDesc = RECORD
      f: Files.File;
      off, len: LONGINT;
      fnt: Fonts.Font;
      col, voff: INTEGER;
      prev, next: Piece
    END;

    Text* = POINTER TO TextDesc;
    Notifier* = PROCEDURE (T: Text; op: INTEGER; beg, end: LONGINT);
    TextDesc* = RECORD
      len*: LONGINT;
      changed*: BOOLEAN;
      notify*: Notifier;
      trailer: Piece;
      pce: Piece;  (*cache*)
      org: LONGINT (*cache*)
    END;

    Reader* = RECORD
      eot*: BOOLEAN;
      fnt*: Fonts.Font;
      col*, voff*: INTEGER;
      ref: Piece;
      org: LONGINT;
      off: LONGINT;
      rider: Files.Rider
    END;

    Scanner* = RECORD (Reader)
      nextCh*: CHAR;
      line*, class*: INTEGER;
      i*: LONGINT;
      x*: REAL;
      y*: LONGREAL;
      c*: CHAR;
      len*: INTEGER;
      s*: ARRAY 32 OF CHAR
    END;

    Buffer* = POINTER TO BufDesc;
    BufDesc* = RECORD
      len*: LONGINT;
      header, last: Piece
    END;

    Writer* = RECORD
      buf*: Buffer;
      fnt*: Fonts.Font;
      col*, voff*: INTEGER;
      rider: Files.Rider
    END;     

```
## Variables:
```
 TrailerFile: Files.File;

```
## Procedures:
---

`  PROCEDURE Trailer(): Piece;` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L77)


`  PROCEDURE Load* (VAR R: Files.Rider; T: Text);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L83)


`  PROCEDURE Open* (T: Text; name: ARRAY OF CHAR);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L109)


`  PROCEDURE Store* (VAR W: Files.Rider; T: Text);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L127)


`  PROCEDURE Close*(T: Text; name: ARRAY OF CHAR);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L161)


`  PROCEDURE OpenBuf* (B: Buffer);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L169)


`  PROCEDURE FindPiece (T: Text; pos: LONGINT; VAR org: LONGINT; VAR pce: Piece);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L174)


`  PROCEDURE SplitPiece (p: Piece; off: LONGINT; VAR pr: Piece);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L186)


`  PROCEDURE Save* (T: Text; beg, end: LONGINT; B: Buffer);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L201)


`  PROCEDURE Copy* (SB, DB: Buffer);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L219)


`  PROCEDURE Insert* (T: Text; pos: LONGINT; B: Buffer);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L228)


`  PROCEDURE Append* (T: Text; B: Buffer);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L247)


`  PROCEDURE Delete* (T: Text; beg, end: LONGINT; B: Buffer);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L251)


`  PROCEDURE ChangeLooks* (T: Text; beg, end: LONGINT; sel: SET; fnt: Fonts.Font; col, voff: INTEGER);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L269)


`  PROCEDURE Attributes*(T: Text; pos: LONGINT; VAR fnt: Fonts.Font; VAR col, voff: INTEGER);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L286)


`  PROCEDURE OpenReader* (VAR R: Reader; T: Text; pos: LONGINT);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L293)


`  PROCEDURE Read* (VAR R: Reader; VAR ch: CHAR);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L300)


`  PROCEDURE Pos* (VAR R: Reader): LONGINT;` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L311)


`  PROCEDURE OpenScanner* (VAR S: Scanner; T: Text; pos: LONGINT);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L317)


`  PROCEDURE Ten(n: INTEGER): REAL;` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L325)


`  PROCEDURE Scan* (VAR S: Scanner);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L335)


`  PROCEDURE OpenWriter* (VAR W: Writer);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L402)


`  PROCEDURE SetFont* (VAR W: Writer; fnt: Fonts.Font);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L408)


`  PROCEDURE SetColor* (VAR W: Writer; col: INTEGER);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L412)


`  PROCEDURE SetOffset* (VAR W: Writer; voff: INTEGER);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L416)


`  PROCEDURE Write* (VAR W: Writer; ch: CHAR);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L420)


`  PROCEDURE WriteLn* (VAR W: Writer);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L433)


`  PROCEDURE WriteString* (VAR W: Writer; s: ARRAY OF CHAR);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L437)


`  PROCEDURE WriteInt* (VAR W: Writer; x, n: LONGINT);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L443)


`  PROCEDURE WriteHex* (VAR W: Writer; x: LONGINT);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L459)


` PROCEDURE WriteReal* (VAR W: Writer; x: REAL; n: INTEGER);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L470)


`  PROCEDURE WriteRealFix* (VAR W: Writer; x: REAL; n, k: INTEGER);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L500)


`  PROCEDURE WritePair(VAR W: Writer; ch: CHAR; x: LONGINT);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L521)


`  PROCEDURE WriteClock* (VAR W: Writer; d: LONGINT);` [(source)](https://github.com/io-orig/System/blob/main/Texts.Mod#L526)
