import openpyxl

wb = openpyxl.load_workbook('AI Features/SnoreClinics-AI-Features.xlsx', data_only=True)
sheet = wb.active
for row in sheet.iter_rows(values_only=True):
    # Only print rows that aren't entirely empty
    if any(cell is not None for cell in row):
        print(" | ".join([str(cell) if cell is not None else "" for cell in row]))
