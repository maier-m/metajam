context("download_d1_data")

test_that("test Arctic Data Center data URL (fully up to date data file)", {
  temp_dir <- tempdir()
  out <- download_d1_data("https://cn.dataone.org/cn/v2/resolve/urn:uuid:a2834e3e-f453-4c2b-8343-99477662b570", 
                          temp_dir)
  files <- list.files(out)
  
  expect_equal(length(files), 4)
  expect_true(any(stringr::str_detect(files, "attribute_metadata.csv")))
  expect_true(any(stringr::str_detect(files, "full_metadata.xml")))
  expect_true(any(stringr::str_detect(files, "summary_metadata.csv")))
  
  folder_name <- stringr::str_extract(out, "[^/]*$")
  expect_true(stringr::str_detect(folder_name, "^doi")) #starts with doi
  
  # remove files
  file.remove(list.files(out, recursive = TRUE, full.names = TRUE))
  file.remove(out)
})

test_that("test Arctic Data Center data URL (fully up to date data file) with one data table", {
  temp_dir <- tempdir()
  out <- download_d1_data("https://cn.dataone.org/cn/v2/resolve/urn:uuid:a2834e3e-f453-4c2b-8343-99477662b570", 
                          temp_dir)
  files <- list.files(out)
  
  expect_equal(length(files), 4)
  expect_true(any(stringr::str_detect(files, "attribute_metadata.csv")))
  expect_true(any(stringr::str_detect(files, "full_metadata.xml")))
  expect_true(any(stringr::str_detect(files, "summary_metadata.csv")))
  
  folder_name <- stringr::str_extract(out, "[^/]*$")
  expect_true(stringr::str_detect(folder_name, "^doi")) #starts with doi
  
  # remove files
  file.remove(list.files(out, recursive = TRUE, full.names = TRUE))
  file.remove(out)
})

test_that("test Arctic Data Center data URL (fully up to date data file) with multiple data tables", {
  temp_dir <- tempdir()
  out <- download_d1_data("https://cn.dataone.org/cn/v2/resolve/urn:uuid:a4f85031-0b91-4d92-ba0a-b02f216bba64", 
                          temp_dir)
  files <- list.files(out)
  
  expect_equal(length(files), 5)
  expect_true(any(stringr::str_detect(files, "attribute_metadata.csv")))
  expect_true(any(stringr::str_detect(files, "attribute_factor_metadata.csv")))
  expect_true(any(stringr::str_detect(files, "full_metadata.xml")))
  expect_true(any(stringr::str_detect(files, "summary_metadata.csv")))
  
  folder_name <- stringr::str_extract(out, "[^/]*$")
  expect_true(stringr::str_detect(folder_name, "^doi")) #starts with doi
  
  # remove files
  file.remove(list.files(out, recursive = TRUE, full.names = TRUE))
  file.remove(out)
})
