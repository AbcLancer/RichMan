
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00433d40(void *this,byte param_1)

{
  void *this_00;
  uint uVar1;
  
  if ((param_1 & 2) != 0) {
    FUN_004361b0(this);
    if (*(int *)((int)this + 0x3c) == 2) {
      FUN_0043cb00(DAT_004fe7ac,0x1f7,(byte *)0x0,this);
      return;
    }
    FUN_00439bf0((undefined4 *)0x1,this,(byte *)0x0);
    this_00 = (void *)FUN_0043a440(&DAT_004f1b08,*(int *)(*(int *)((int)this + 0xc) + 0x78));
    if ((this_00 != (void *)0x0) && (this_00 != this)) {
      FUN_00436570(this_00,0xf);
      if (_DAT_00508fa0 <= (float)*(double *)((int)this_00 + 0x1c8)) {
        if ((param_1 & 1) == 0) {
          uVar1 = FUN_00434e60(this,1,(short *)0x0,this_00);
          if (uVar1 != 0) {
            FUN_00436810(this_00,0x24,0);
          }
        }
        else {
          FUN_0043ff30(*(void **)((int)this_00 + 0x1c0),(byte *)0x2710,0);
          FUN_0043ffe0(*(void **)((int)this + 0x1c0),(byte *)0x2710,0);
        }
      }
    }
  }
  if ((param_1 & 1) != 0) {
    FUN_00439bf0((undefined4 *)0x2,this,(byte *)0x0);
  }
  return;
}

