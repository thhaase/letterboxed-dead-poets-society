library(httr)
library(xml2)

scrape_page <- function(page_number) {
  url <- paste0(
    "https://letterboxd.com/film/dead-poets-society/reviews/page/",
    page_number, "/"
  )
  
  response <- GET(
    url,
    user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
  )
  
  if (status_code(response) != 200) {
    warning(paste("Page", page_number, "returned status", status_code(response)))
    return(NULL)
  }
  
  page <- read_html(content(response, as = "text"))
  
  # reviews live inside <article class="production-viewing">
  reviews <- xml_find_all(page, "//article[contains(@class, 'production-viewing')]")
  
  if (length(reviews) == 0) {
    warning(paste("No reviews found on page", page_number))
    return(NULL)
  }
  
  results <- lapply(reviews, function(rev) {
    name_node <- xml_find_first(rev, ".//strong[contains(@class, 'displayname')]")
    name <- if (!is.na(name_node)) xml_text(name_node, trim = TRUE) else NA
    
    comment_nodes <- xml_find_all(rev, ".//div[contains(@class, 'body-text')]//p")
    comment <- if (length(comment_nodes) > 0) {
      paste(xml_text(comment_nodes, trim = TRUE), collapse = " ")
    } else {
      NA
    }
    
    date_node <- xml_find_first(rev, ".//time[contains(@class, 'timestamp')]")
    date <- if (!is.na(date_node)) xml_attr(date_node, "datetime") else NA
    
    rating_node <- xml_find_first(rev, ".//span[contains(@class, 'rating')]")
    if (!is.na(rating_node)) {
      rating_raw <- xml_text(rating_node, trim = TRUE)
      stars <- nchar(gsub("[^★]", "", rating_raw))
      half <- grepl("\u00BD", rating_raw)  # ½ character
      rating <- if (half) stars + 0.5 else as.numeric(stars)
    } else {
      rating <- NA
    }
    
    data.frame(
      name = name,
      comment = comment,
      date = date,
      rating = rating,
      stringsAsFactors = FALSE
    )
  })
  
  do.call(rbind, results)
}

# === Main ===
num_pages <- 256
all_pages <- vector("list", num_pages)

for (page_number in seq_len(num_pages)) {
  Sys.sleep(sample(20:50, 1) / 10)
  cat("Scraping page:", page_number, "\n")
  all_pages[[page_number]] <- scrape_page(page_number)
}

df <- do.call(rbind, all_pages)
cat("Done. Total reviews scraped:", nrow(df), "\n")

write.csv(df, "comments.csv")