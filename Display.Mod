(* begin-module-short-description
renders text and graphics to the framebuffer.
end-module-short-description *)

(* begin-module-use-description
Module Display implements the drawing primitives for the frame buffer device in Oberon.

A pattern is an array of bytes; the first is its width (< 32), the second its height, the rest the raster data.

end-module-use-description *)
(* begin-module-develop-description

(NW 5.11.2013 / 17.1.2019 / PDW 21.1.2019 / JS 2020 / CP 2020)

**Display** is the interface to the hardware framebuffer in Oberon.

On initialization the origial base address is queried for a magic value to determine
if the base has moved and if the resolution is something other than 1024x768.

A pattern is an array of bytes; the first is its width (< 32), the second its height, the rest the raster data.

end-module-develop-description *)
MODULE Display;  (*NW 5.11.2013 / 17.1.2019 / PDW 21.1.2019 *)
(* Color based on the 16-bit version by Joerg Straube *)
  IMPORT SYSTEM;

  CONST 
    black* = 0;  (*black = background*)
    replace* = 0; paint* = 1; invert* = 2;  (*modes*)
    (* base = 0E7F00H; *)  (*adr of 1024 x 768 pixel, monocolor display frame*)
    (* In the emulator, the frame buffer address might be moved depending on memory configuration *)

  TYPE 
    Frame* = POINTER TO FrameDesc;
    FrameMsg* = RECORD END ;
    Handler* = PROCEDURE (F: Frame; VAR M: FrameMsg);
    FrameDesc* = RECORD next*, dsc*: Frame;
        X*, Y*, W*, H*: INTEGER;
        handle*: Handler
      END ;

  VAR 
    Base*, Width*, Height*, Depth*, white*, Span, Colors, Colmask, pp8, pp32: INTEGER;
    arrow*, star*, hook*, updown*, block*, top*, bot*, cross*, grey*: INTEGER;
    (*a pattern is an array of bytes; the first is its width (< 32), the second its height, the rest the raster*)

  (* begin-section-description
## ---------- General
  end-section-description *)

  (* begin-procedure-description
---
**Handle** dispatches a handle message to the appropriate frame.
  end-procedure-description *)
  PROCEDURE Handle*(F: Frame; VAR M: FrameMsg);
  BEGIN
    IF (F # NIL) & (F.handle # NIL) THEN F.handle(F, M) END
  END Handle;

  (* raster ops *)

  (* begin-section-description
## ---------- Raster Ops
  end-section-description *)

  (* begin-procedure-description
---
**Dot** modifies a pixel on the display.
  end-procedure-description *)
  PROCEDURE Dot*(col, x, y, mode: INTEGER);
    VAR a: INTEGER; pix, color: SET;
  BEGIN a := Base + y * Span + (x DIV pp32)*4;
    x := x MOD pp32 * Depth;
    color := SYSTEM.VAL(SET, LSL(col MOD Colors, x));
    SYSTEM.GET(a, pix);
    IF mode = invert THEN
      SYSTEM.PUT(a, pix / color)
    ELSE (*mode = replace / paint*)
      SYSTEM.PUT(a, pix - SYSTEM.VAL(SET, LSL(white, x)) + color)
    END
  END Dot;



  (* begin-procedure-description
---
**ReplConst** paints a color into a rectangular area or inverts the area.
  end-procedure-description *)
  PROCEDURE ReplConst*(col, x, y, w, h, mode: INTEGER);
    VAR al, ar, a0, a1: INTEGER; left, right, mid, pix, pixl, pixr, color: SET;
  BEGIN al := Base + y * Span; INC(w, x-1);
    ar := w DIV pp32 * 4 + al; al := x DIV pp32 * 4 + al;
    color := SYSTEM.VAL(SET, (col MOD Colors) * Colmask);        (* copy "col" to all PP32 pixels in a word *)
    left := { (x MOD pp32 * Depth).. 31 };
    right := { 0 .. (w MOD pp32 * Depth + (Depth-1)) };
    IF ar = al THEN
      mid := left * right; color := color * mid;
      a1 := al;
      WHILE a1 <= al + (h-1)*Span DO
        SYSTEM.GET(a1, pix);
        IF mode = invert THEN SYSTEM.PUT(a1, pix / color)
        ELSIF col = black THEN SYSTEM.PUT(a1, pix - mid)    (* special color "black" to speed up erasing *)
        ELSE SYSTEM.PUT(a1, pix - mid + color)        (* works for all colors, including "black" *)
        END;
        INC(a1, Span)
      END
    ELSIF ar > al THEN
      a0 := al;
      WHILE a0 <= al + (h-1) * Span DO
        SYSTEM.GET(a0, pixl);
        SYSTEM.GET(ar, pixr);
        IF mode = invert THEN
          SYSTEM.PUT(a0, pixl / (color * left));
          FOR a1 := a0+4 TO ar-4 BY 4 DO SYSTEM.GET(a1, pix); SYSTEM.PUT(a1, pix / color) END;
          SYSTEM.PUT(ar, pixr / (color * right))
        ELSIF col = black THEN (*erase*)
          SYSTEM.PUT(a0, pixl - left);
          FOR a1 := a0+4 TO ar-4 BY 4 DO SYSTEM.PUT(a1, {}) END;
          SYSTEM.PUT(ar, pixr - right)
        ELSE (* ((mode = paint) OR (mode = replace)) & (col # black) *)
          SYSTEM.PUT(a0, pixl - left + color * left);
          FOR a1 := a0+4 TO ar-4 BY 4 DO SYSTEM.PUT(a1, color) END;
          SYSTEM.PUT(ar, pixr - right + color * right)
        END ;
        INC(ar, Span);
        INC(a0, Span)
      END
    END
  END ReplConst;


  (* begin-procedure-description
---
**CopyPattern** copies a bitmap to a location in a color, possibly inverting the destination area.
  end-procedure-description *)
  PROCEDURE CopyPattern*(col, patadr, x, y, mode: INTEGER);  (*only for modes = paint, invert*)
    VAR w, h, b: BYTE;
      i, j, k, len, scrAdr: INTEGER;
      pat, pix, mask, color: SET;
      s: ARRAY 5 OF SET; (* stretched and shifted pattern *)
  BEGIN SYSTEM.GET(patadr, w); SYSTEM.GET(patadr+1, h); INC(patadr, 2);
    color := SYSTEM.VAL(SET, (col MOD Colors) * Colmask);        (* copy "col" to all PP32 pixels in a word *)
    scrAdr := x DIV pp32 * 4 + y * Span + Base; x := x MOD pp32;
    FOR i := 0 TO h-1 DO
      SYSTEM.GET(patadr, b); pat := SYSTEM.VAL(SET, 0+b); INC(patadr);
      IF w > 8 THEN SYSTEM.GET(patadr, b); pat := SYSTEM.VAL(SET, 100H*b) + pat; INC(patadr);
        IF w > 16 THEN SYSTEM.GET(patadr, b); pat := SYSTEM.VAL(SET, 10000H*b) + pat; INC(patadr);
          IF w > 24 THEN SYSTEM.GET(patadr, b); pat := SYSTEM.VAL(SET, 1000000H*b) + pat; INC(patadr) END
        END
      END;
      (* stretch and shift pattern: every bit in pattern is stretched to BPP bits *)
      k := 0; s[0] := {}; mask := SYSTEM.VAL(SET, LSL(white, x * Depth));
      j := 0; len := pp32 - x; IF w < len THEN len := w END;
      (* optimized stretching for small "w" *)
      WHILE j < len DO
        IF j IN pat THEN s[0] := s[0] + mask END;
        mask := ROR(mask, -Depth); INC(j)
      END;
      (* more general, slower stretching for larger "w" *)
      WHILE j < w DO
        IF mask = SYSTEM.VAL(SET, white) THEN INC(k); s[k] := {} END;
        IF j IN pat THEN s[k] := s[k] + mask END;
        mask := ROR(mask, -Depth); INC(j)
      END;
      (* copy stretched and shifted pattern to framebuffer *)
      SYSTEM.GET(scrAdr, pix);
      IF mode = invert THEN
        SYSTEM.PUT(scrAdr, pix / (color * s[0]) );
        WHILE k > 0 DO SYSTEM.GET(k*4 + scrAdr, pix); SYSTEM.PUT(k*4 + scrAdr, pix / (color * s[k])); DEC(k) END
      ELSIF col = white THEN
        SYSTEM.PUT(scrAdr, pix + s[0]);
        WHILE k > 0 DO SYSTEM.GET(k*4 + scrAdr, pix); SYSTEM.PUT(k*4 + scrAdr, pix + s[k]); DEC(k) END
      ELSE
        SYSTEM.PUT(scrAdr, (pix - s[0]) + color * s[0]);
        WHILE k > 0 DO SYSTEM.GET(k*4 + scrAdr, pix); SYSTEM.PUT(k*4 + scrAdr, (pix - s[k]) + color * s[k]); DEC(k) END
      END;
      INC(scrAdr, Span)
    END
  END CopyPattern;



  (* begin-procedure-description
---
**CopyBlock** copies a rectangular area to a location on the display.
  end-procedure-description *)
  PROCEDURE CopyBlock*(sx, sy, w, h, dx, dy, mode: INTEGER); (*only for mode = replace*)
    VAR sa, da, sa0, sa1, d, len: INTEGER;
      u0, u1, u3, v0, v1, v3, n: INTEGER;
      end, step: INTEGER;
      src, dst, spill: SET;
      m0, m1, m2, m3: SET;
  BEGIN
    u0 := sx DIV pp32 * 4; v0 := dx DIV pp32 * 4;
    u1 := sx MOD pp32 * Depth; v1 := dx MOD pp32 * Depth;
    u3 := (sx+w) MOD pp32 * Depth; v3 := (dx+w) MOD pp32 * Depth;
    sa := sy * Span + u0 + Base; da := dy * Span + v0 + Base;
    len := (sx+w) DIV pp32 * 4 - u0;
    d := da - sa; n := u1 - v1;   (* displacement in words and bits *)
    m0 := {v1 .. 31}; m2 := {v3 .. 31}; m3 := m0 / m2;
    IF n >= 0 THEN m1 := {n .. 31} ELSE m1 := {-n .. 31} END;
    IF d >= 0 THEN                  (* copy up, scan down *)
      sa0 := sa + (h-1)*Span; end := sa - Span; step := -Span
    ELSE                    (* copy down, scan up *)
      sa0 := sa; end := sa + h*Span; step := Span
    END ;
    WHILE sa0 # end DO
      IF n >= 0 THEN                (* shift right *)
        IF v1 + w * Depth < 32 THEN
          SYSTEM.GET(sa0, src); src := ROR(src, n);
          SYSTEM.GET(sa0+d, dst);
          SYSTEM.PUT(sa0+d, (src * m3) + (dst - m3))
        ELSE
          SYSTEM.GET(sa0+len, src); src := ROR(src, n);
          SYSTEM.GET(sa0+len+d, dst);
          SYSTEM.PUT(sa0+len+d, (dst * m2) + (src - m2));
          spill := src - m1;
          FOR sa1 := sa0 + len-4 TO sa0+4  BY -4 DO
            SYSTEM.GET(sa1, src); src := ROR(src, n);
            SYSTEM.PUT(sa1+d, spill + (src * m1));
            spill := src - m1
          END ;
          SYSTEM.GET(sa0, src); src := ROR(src, n);
          SYSTEM.GET(sa0+d, dst);
          SYSTEM.PUT(sa0+d, (src * m0) + (dst - m0))
        END
      ELSE (* shift left *)
        SYSTEM.GET(sa0, src); src := ROR(src, n);
        SYSTEM.GET(sa0+d, dst);
        IF v1 + w * Depth < 32 THEN
          SYSTEM.PUT(sa0+d, (dst - m3) + (src * m3))
        ELSE
          SYSTEM.PUT(sa0+d, (dst - m0) + (src * m0));
          spill := src - m1;
          FOR sa1 := sa0 + 4 TO sa0 + len-4 BY 4 DO
            SYSTEM.GET(sa1, src); src := ROR(src, n);
            SYSTEM.PUT(sa1+d, spill + (src * m1));
            spill := src - m1
          END ;
          SYSTEM.GET(sa0+len, src); src := ROR(src, n);
          SYSTEM.GET(sa0+len+d, dst);
          SYSTEM.PUT(sa0+len+d, (src - m2) + (dst * m2))
        END
      END ;
      INC(sa0, step)
    END
  END CopyBlock;



  (* begin-procedure-description
---
**ReplPattern** replicates a pattern over a rectangular area of the display.
  end-procedure-description *)
  PROCEDURE ReplPattern*(col, patadr, x, y, w, h, mode: INTEGER);
  (* BW pattern width = 32, fixed; pattern starts at patadr+4, for mode = invert only *)
  (* Color pattern width = 8, fixed; pattern starts at patadr+4, for mode = invert only *)
  (* NOTE that BW patterns will be converted in place on first call. *)
    VAR al, ar, a0, a1: INTEGER;
      pta0, pta1: INTEGER;  (*pattern addresses*)
      pw, ph: BYTE;
      left, right, mid, pix, pat, color: SET;
  BEGIN al := Base + y*Span; SYSTEM.GET(patadr+1, ph); SYSTEM.GET(patadr, pw);
    IF pw = 32 THEN pw := 8; SYSTEM.PUT(patadr, pw);
      FOR a0 := 1 TO ph DO
        SYSTEM.GET(patadr+4*a0, pix);
        pat := {};
        FOR ar := 0 TO 3 DO
          IF (pix * {ar} # {}) THEN pat := pat + {ar*4 .. ar*4+3} END;
          IF (pix * {12+ar} # {}) THEN pat := pat + {(ar+4)*4 .. (ar+4)*4+3} END
        END;
        SYSTEM.PUT(patadr+4*a0, pat)
      END
    END;
    ASSERT(pw = 8);          (* width MUST be 8 *)
    pta0 := patadr+4; pta1 := ph*4 + pta0;
    color := SYSTEM.VAL(SET, (col MOD Colors) * Colmask);        (* copy "col" to all PP32 pixels in a word *)
    INC(w, x-1);
    ar := (w DIV pp32) *4 + al; al := (x DIV pp32) *4 + al;
    left := { ((x MOD pp32) * Depth) .. 31}; right := {0 .. ((w MOD pp32) * Depth + (Depth-1))};
    IF ar = al THEN
      mid := left * right;
      a1 := al;
      WHILE a1 <= al + (h-1)*Span DO
        SYSTEM.GET(pta0, pat); pat := pat * color;
        SYSTEM.GET(a1, pix); SYSTEM.PUT(a1, (pix - mid) + (pix/pat * mid));
        INC(pta0, 4);
        IF pta0 = pta1 THEN pta0 := patadr+4 END;
        INC(a1,Span)
      END
    ELSIF ar > al THEN
      a0 := al;
      WHILE a0 <= al + (h-1)*Span DO
        SYSTEM.GET(pta0, pat); pat := pat * color;
        SYSTEM.GET(a0, pix); SYSTEM.PUT(a0, (pix - left) + (pix/pat * left));
        FOR a1 := a0+4 TO ar-4 BY 4 DO SYSTEM.GET(a1, pix); SYSTEM.PUT(a1, pix/pat) END;
        SYSTEM.GET(ar, pix); SYSTEM.PUT(ar, (pix - right) + (pix/pat * right));
        INC(pta0, 4); INC(ar, Span);
        IF pta0 = pta1 THEN pta0 := patadr+4 END;
        INC(a0,Span)
      END
    END
  END ReplPattern;


  (* begin-section-description
## ---------- Initialization
  end-section-description *)

  (* begin-procedure-description
---
**InitResolution** determines the frame buffer base address and screen geometry.
  end-procedure-description *)
  PROCEDURE InitResolution;
  VAR magic, y: INTEGER;
  BEGIN
    Base := 0E7F00H;
    SYSTEM.GET(Base, magic);
    IF magic = 53697A65H THEN
      SYSTEM.GET(Base + 4, Width);
      SYSTEM.GET(Base + 8, Height);
      Span := 128; Depth := 1
    ELSIF magic = 53697A66H THEN
      SYSTEM.GET(Base + 4, Width);
      SYSTEM.GET(Base + 8, Height);
      Span := Width DIV 8; Depth := 1
    ELSIF magic = 53697A67H THEN
      SYSTEM.GET(Base + 4, Width);
      SYSTEM.GET(Base + 8, Height);
      SYSTEM.GET(Base + 12, Base);
      Span := Width DIV 8; Depth := 1
    ELSIF magic = 53697A68H THEN  
      SYSTEM.GET(Base + 4, Width);
      SYSTEM.GET(Base + 8, Height);
      SYSTEM.GET(Base + 16, Depth);
      SYSTEM.GET(Base + 12, Base);
      Span := (Width DIV 8) * Depth;
      LED(98);
    ELSE
      Width := 1024; Height := 768; Depth := 1; Span := 128
    END;
    pp8 := 8 DIV Depth;
    pp32 := pp8 * 4;
    Colors := 2; Colmask := 0FFFFFFFFH; white := 1;
    IF Depth = 2 THEN Colors := 4; Colmask := 55555555H; white := 3 END;
    IF Depth = 4 THEN Colors := 16; Colmask := 11111111H; white := 15 END;
    LED(99);
    LED(Depth);
    y:=0; WHILE y < Height DO Dot(white,y,y,paint); INC(y) END
  END InitResolution;

  (* begin-procedure-description
---
**The initialzation code for this module** detects the screen origin and geometry and then installs icons for cursors and a background pattern.
  end-procedure-description *)
BEGIN InitResolution;
  arrow := SYSTEM.ADR($0F0F 0060 0070 0038 001C 000E 0007 8003 C101 E300 7700 3F00 1F00 3F00 7F00 FF00$);
  star := SYSTEM.ADR($0F0F 8000 8220 8410 8808 9004 A002 C001 7F7F C001 A002 9004 8808 8410 8220 8000$);
  hook := SYSTEM.ADR($0C0C 070F 8707 C703 E701 F700 7F00 3F00 1F00 0F00 0700 0300 01$);
  updown := SYSTEM.ADR($080E 183C 7EFF 1818 1818 1818 FF7E3C18$);
  block := SYSTEM.ADR($0808 FFFF C3C3 C3C3 FFFF$);
  top := SYSTEM.ADR($0808 1818 1818 1818 FFFF$);
  bot := SYSTEM.ADR($0808 FFFF 1818 1818 1818$);
  cross := SYSTEM.ADR($0F0F 0140 0220 0410 0808 1004 2002 4001 0000 4001 2002 1004 0808 0410 0220 0140$);
  grey := SYSTEM.ADR($2002 0000 5555 5555 AAAA AAAA$)
END Display.
