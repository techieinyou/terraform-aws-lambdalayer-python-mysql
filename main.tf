locals {
  python_runtimes = ["python3.12", "python3.11", "python3.10", "python3.9", "python3.8"]
}

locals {
  temp_folder      = "lambdalayer"
  package_source   = "${local.temp_folder}\\mysql\\python"
  package_file     = "${local.temp_folder}\\python-mysql.zip"
  folder_2_install = "${local.temp_folder}\\mysql\\python\\lib\\${var.python_runtime}\\site-packages"
  file_2_verify    = "${local.folder_2_install}\\mysql\\__init__.py"

  lambda_runtime = contains(local.python_runtimes, var.python_runtime) ? var.python_runtime : local.python_runtimes[0]
}

resource "null_resource" "create_folder" {

  # trigger on timestamp change will make sure local-exec runs always
  triggers = {
    always_run = "${timestamp()}"
  }

  # skip this block if the package already exists
  count = fileexists(pathexpand("${local.file_2_verify}")) ? 0 : 1

  # create folder and sub folders to install Python mysql library
  provisioner "local-exec" {
    # command = "if not exist tmp\\mysql\\python\\lib\\python3.9\\site-packages mkdir tmp\\mysql\\python\\lib\\python3.9\\site-packages"
    command = "mkdir ${local.folder_2_install}"
  }
}

resource "time_sleep" "until_folder_creation" {
  depends_on      = [null_resource.create_folder]
  create_duration = "2s"
}

# Pre-requisite : Python 3
resource "null_resource" "install_python_mysql" {

  # depends_on = [null_resource.create_folder]

  # trigger on timestamp change will make sure local-exec runs always
  triggers = {
    always_run = "${timestamp()}"
  }

  # skip this block if the package already exists
  count = fileexists(pathexpand(local.package_file)) ? 0 : 1

  # install Python mysql library
  provisioner "local-exec" {
    # command = "pip3 install mysql -t ${local.folder_2_install}"
    command = "pip3 install mysql-connector-python -t ${local.folder_2_install}"
  }
}

resource "time_sleep" "until_install_completion" {
  depends_on      = [null_resource.install_python_mysql]
  create_duration = "10s"
}

# Pre-requisite : Python 3
resource "null_resource" "create_package" {

  depends_on = [time_sleep.until_install_completion]

  # trigger on timestamp change will make sure local-exec runs always
  triggers = {
    always_run = "${timestamp()}"
  }

  # skip this block if the package already exists
  count = fileexists(pathexpand(local.package_file)) ? 0 : 1

  # create package of mysql library folder
  provisioner "local-exec" {
    command = "python -m zipfile -c ${local.package_file} ${local.package_source}"
  }
}

# creates lambda layer
resource "aws_lambda_layer_version" "python_mysql" {
  depends_on          = [null_resource.create_package]
  filename            = local.package_file
  layer_name          = var.layer_name
  compatible_runtimes = [var.python_runtime]
}
