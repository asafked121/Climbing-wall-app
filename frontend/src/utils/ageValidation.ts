export const calculateAge = (birthMonth: number, birthYear: number): number => {
  const today = new Date();
  const currentYear = today.getFullYear();
  const currentMonth = today.getMonth() + 1; // getMonth() returns 0-11

  let age = currentYear - birthYear;

  // If the birth month hasn't happened yet this year, they are one year younger
  if (birthMonth > currentMonth) {
    age--;
  }

  return age;
};

export const isOldEnough = (
  birthMonth: number,
  birthYear: number,
  requiredAge: number = 13,
): boolean => {
  return calculateAge(birthMonth, birthYear) >= requiredAge;
};
