
void * __cdecl FUN_00432830(int param_1,int param_2)

{
  if (param_1 == 0) {
    return (void *)0x0;
  }
  if (param_1 != 1) {
    if (param_1 == DAT_004fdff4) {
      if (param_2 == DAT_004fdf5c) {
        return DAT_004fdf60;
      }
    }
    else {
      FUN_0047a0c0(DAT_004fe1b4,0,0,*(int *)(&DAT_004fdfe8 + param_1 * 8));
      FUN_0047a0c0(DAT_004fe1b8,0,0,*(int *)(&DAT_004fdfec + param_1 * 8));
    }
    FUN_0047a0c0(DAT_004fdf60,0,0,(&DAT_004fdf64)[param_2 + -8 + param_1 * 4]);
    DAT_004fdff4 = param_1;
    DAT_004fdf5c = param_2;
    return DAT_004fdf60;
  }
  return (void *)0x0;
}

