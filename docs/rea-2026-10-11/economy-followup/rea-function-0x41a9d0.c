
void __thiscall FUN_0041a9d0(void *this,undefined4 param_1,float param_2)

{
  switch(param_1) {
  case 1:
    *(int *)this = *(int *)this + (int)param_2;
    return;
  case 2:
    *(int *)((int)this + 4) = *(int *)((int)this + 4) + (int)param_2;
    return;
  case 3:
    *(int *)((int)this + 8) = *(int *)((int)this + 8) + (int)param_2;
    return;
  case 4:
    *(float *)((int)this + 0xc) = param_2 + *(float *)((int)this + 0xc);
    return;
  case 5:
    *(float *)((int)this + 0x10) = param_2 + *(float *)((int)this + 0x10);
    return;
  case 6:
    *(float *)((int)this + 0x14) = param_2 + *(float *)((int)this + 0x14);
    return;
  case 7:
    *(float *)((int)this + 0x18) = param_2 + *(float *)((int)this + 0x18);
  }
  return;
}

