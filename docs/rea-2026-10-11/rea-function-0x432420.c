
void __thiscall FUN_00432410(void *this,int param_1)

{
  float fVar1;
  
  *(byte *)((int)this + 0x40) = *(byte *)((int)this + 0x40) | 1;
  fVar1 = (float)param_1 + *(float *)((int)this + 0x38);
  *(float *)((int)this + 0x38) = fVar1;
  if (*(float *)((int)this + 0x34) < fVar1) {
    *(undefined4 *)((int)this + 0x38) = *(undefined4 *)((int)this + 0x34);
  }
  return;
}

