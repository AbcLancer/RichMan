
undefined4 __cdecl FUN_004328d0(int param_1,int param_2,int param_3)

{
  if (param_1 == 0) {
    return 0;
  }
  if (param_1 == 1) {
    return 0;
  }
  return (&DAT_004fe040)[*(int *)(&DAT_004fe1a8 + param_2 * 4) + (param_1 * 5 + -10) * 2 + param_3];
}

