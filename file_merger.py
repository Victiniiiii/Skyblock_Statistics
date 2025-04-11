def read_names_from_file(file_path):
    with open(file_path, 'r') as file:
        return [line.strip() for line in file.readlines()]

def merge_and_sort_names(file1, file2):
    names_list1 = read_names_from_file(file1)
    names_list2 = read_names_from_file(file2)
    
    merged_names = set(names_list1 + names_list2)
    sorted_names = sorted(merged_names)
    
    return sorted_names

def save_names_to_file(names, file_path):
    with open(file_path, 'w') as file:
        for name in names:
            file.write(name + '\n')

# Example usage
file1 = 'output.txt'
file2 = 'player_list.txt'
file3 = 'file3.txt'

sorted_names = merge_and_sort_names(file1, file2)
save_names_to_file(sorted_names, file3)

print(f"The merged and sorted names have been saved to {file3}")
