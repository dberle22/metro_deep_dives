build_cluster_seed_tracts_product <- function(scored_tracts, cluster_top_share = MODEL_PARAMS$cluster_top_share) {
  cluster_cutoff_n <- ceiling(nrow(scored_tracts) * cluster_top_share)

  scored_tracts %>%
    arrange(desc(tract_score)) %>%
    mutate(
      cluster_seed_rank = row_number(),
      is_cluster_seed = cluster_seed_rank <= cluster_cutoff_n,
      cluster_top_share = cluster_top_share,
      cluster_cutoff_n = cluster_cutoff_n
    ) %>%
    filter(is_cluster_seed) %>%
    select(
      tract_geoid,
      tract_score,
      tract_rank,
      cluster_seed_rank,
      cluster_top_share,
      cluster_cutoff_n,
      eligible_v1
    )
}
