
undefined4 __thiscall FUN_0041a950(void *this,undefined4 param_1)

{
  switch(param_1) {
  case 1:
    return *(undefined4 *)this;
  case 2:
    return *(undefined4 *)((int)this + 4);
  case 3:
    return *(undefined4 *)((int)this + 8);
  case 4:
    return *(undefined4 *)((int)this + 0xc);
  case 5:
    return *(undefined4 *)((int)this + 0x10);
  case 6:
    return *(undefined4 *)((int)this + 0x14);
  case 7:
    return *(undefined4 *)((int)this + 0x18);
  default:
    return 0;
  }
}

