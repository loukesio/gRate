test_that("long layouts join metadata by well", {
  plate <- synthetic_plate()
  layout <- data.frame(
    well = gRate:::gr_all_wells(),
    strain = rep(c("wt", "mut"), 48),
    replicate = rep(1:4, each = 24)
  )
  plate <- gr_layout(plate, layout)

  expect_true(all(c("strain", "replicate") %in% names(plate$data)))
  expect_identical(
    unique(plate$data$strain[plate$data$well == "A1"]),
    "wt"
  )
})

test_that("layout well ids are normalised before joining", {
  plate <- synthetic_plate()
  layout <- data.frame(Well = c("A01", "a2"), strain = c("wt", "mut"))
  expect_warning(plate <- gr_layout(plate, layout), "no layout entry")
  expect_identical(unique(plate$data$strain[plate$data$well == "A1"]), "wt")
  expect_identical(unique(plate$data$strain[plate$data$well == "A2"]), "mut")
  expect_true(all(is.na(plate$data$strain[plate$data$well == "B1"])))
})

test_that("grid layouts become a single metadata column", {
  plate <- synthetic_plate()
  grid <- as.data.frame(matrix(rep(paste0("s", 1:12), 8), nrow = 8,
                               byrow = TRUE))
  plate <- gr_layout(plate, grid, name = "strain")
  expect_identical(unique(plate$data$strain[plate$data$col == 3]), "s3")

  # with a leading row-letter column, in scrambled order
  grid2 <- cbind(data.frame(row = rev(LETTERS[1:8])),
                 as.data.frame(matrix("x", nrow = 8, ncol = 12)))
  grid2[grid2$row == "C", 5] <- "special"
  plate2 <- gr_layout(synthetic_plate(), grid2, name = "content")
  expect_identical(
    unique(plate2$data$content[plate2$data$well == "C4"]),
    "special"
  )
})

test_that("layout errors are informative", {
  plate <- synthetic_plate()
  expect_error(gr_layout(plate, data.frame(x = 1)), "8 rows x 12 columns")
  expect_error(
    gr_layout(plate, data.frame(well = c("A1", "A1"), s = 1:2)),
    "duplicated"
  )
  expect_warning(
    gr_layout(plate, data.frame(well = gRate:::gr_all_wells()[1:5],
                                s = 1)),
    "no layout entry"
  )
  plate2 <- gr_layout(plate, data.frame(well = gRate:::gr_all_wells(),
                                        strain = "wt"))
  expect_error(
    gr_layout(plate2, data.frame(well = "A1", strain = "dup")),
    "already present"
  )
  expect_error(gr_layout(plate, layout = 1), "data frame or a file path")
})

test_that("layouts read from CSV files", {
  plate <- synthetic_plate()
  layout <- data.frame(well = gRate:::gr_all_wells(), strain = "wt")
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(layout, path, row.names = FALSE)
  plate <- gr_layout(plate, path)
  expect_identical(unique(plate$data$strain), "wt")
})

test_that("bio_rep and tech_rep columns can be designated", {
  plate <- synthetic_plate()
  layout <- data.frame(
    well = gRate:::gr_all_wells(),
    strain = "wt",
    biol = rep(1:4, each = 24),
    tech = rep(1:2, 48)
  )
  plate <- gr_layout(plate, layout, bio_rep = "biol", tech_rep = "tech")
  expect_true(all(c("bio_rep", "tech_rep") %in% names(plate$data)))
  expect_output(print(plate), "replicates: 4 biological x 2 technical")
})

test_that("bio_rep/tech_rep columns are picked up by name automatically", {
  plate <- gr_layout(
    synthetic_plate(),
    data.frame(well = gRate:::gr_all_wells(), bio_rep = 1, tech_rep = 1)
  )
  expect_output(print(plate), "replicates: 1 biological x 1 technical")
})

test_that("replicate designation errors are informative", {
  plate <- synthetic_plate()
  layout <- data.frame(well = gRate:::gr_all_wells(), biol = 1, bio_rep = 2)
  expect_error(
    gr_layout(plate, data.frame(well = "A1", s = 1), bio_rep = "nope"),
    "not found in the layout"
  )
  expect_error(
    gr_layout(plate, layout, bio_rep = "biol"),
    "already has a 'bio_rep' column"
  )
})
